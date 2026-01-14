"""
Face Recognition Service for School Management System
Uses OpenCV and face_recognition library for face detection and recognition
"""

import os
import io
import json
import logging
from typing import List, Optional
from datetime import datetime

import numpy as np
import cv2
import face_recognition
from PIL import Image
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Face Recognition Service",
    description="Face detection and recognition service for attendance management",
    version="1.0.0"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Key Authentication Middleware
from fastapi import Header, HTTPException as FastAPIHTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

class APIKeyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Skip auth for health check
        if request.url.path == "/health":
            return await call_next(request)
        
        # Check for API key
        api_key = request.headers.get("X-API-Key")
        expected_key = os.getenv("API_KEY")
        
        if not expected_key:
            logger.warning("API_KEY not set in environment variables - authentication disabled!")
        elif not api_key:
            return JSONResponse(
                status_code=401,
                content={"detail": "API key is missing"}
            )
        elif api_key != expected_key:
            return JSONResponse(
                status_code=403,
                content={"detail": "Invalid API key"}
            )
        
        response = await call_next(request)
        return response

from fastapi.responses import JSONResponse

# Add API key middleware
app.add_middleware(APIKeyMiddleware)

# Models
class KnownFace(BaseModel):
    id: str
    rollNumber: str
    name: str
    encoding: List[float]

class RecognizedFace(BaseModel):
    id: str
    rollNumber: str
    name: str
    confidence: float
    location: dict

class RecognitionResponse(BaseModel):
    success: bool
    message: str
    total_faces_detected: int
    recognized: List[RecognizedFace]
    unrecognized_count: int
    processing_time_ms: float

class EncodingResponse(BaseModel):
    success: bool
    message: str
    encoding: Optional[List[float]] = None
    face_count: int

# Helper functions
def load_image_from_upload(file_bytes: bytes) -> np.ndarray:
    """Load image from uploaded bytes"""
    image = Image.open(io.BytesIO(file_bytes))
    # Convert to RGB if necessary
    if image.mode != 'RGB':
        image = image.convert('RGB')
    return np.array(image)

def detect_faces(image: np.ndarray) -> List[tuple]:
    """Detect faces in image and return locations"""
    # Use HOG-based detection (faster) or CNN (more accurate)
    face_locations = face_recognition.face_locations(image, model="hog")
    return face_locations

def get_face_encodings(image: np.ndarray, face_locations: List[tuple]) -> List[np.ndarray]:
    """Get face encodings for detected faces"""
    encodings = face_recognition.face_encodings(image, face_locations)
    return encodings

def compare_faces(known_encodings: List[np.ndarray], face_encoding: np.ndarray, tolerance: float = 0.6) -> tuple:
    """Compare face encoding with known encodings"""
    if len(known_encodings) == 0:
        return -1, 0.0
    
    # Calculate face distances
    face_distances = face_recognition.face_distance(known_encodings, face_encoding)
    
    # Find best match
    best_match_index = np.argmin(face_distances)
    best_distance = face_distances[best_match_index]
    
    # Convert distance to confidence (0-1, higher is better)
    confidence = 1 - best_distance
    
    if best_distance <= tolerance:
        return best_match_index, confidence
    
    return -1, confidence

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "face-recognition",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.post("/encode", response_model=EncodingResponse)
async def encode_face(image: UploadFile = File(...)):
    """
    Extract face encoding from an image.
    Used when registering a new student's face.
    """
    try:
        # Read image
        contents = await image.read()
        img = load_image_from_upload(contents)
        
        # Detect faces
        face_locations = detect_faces(img)
        
        if len(face_locations) == 0:
            return EncodingResponse(
                success=False,
                message="No face detected in the image",
                face_count=0
            )
        
        if len(face_locations) > 1:
            return EncodingResponse(
                success=False,
                message=f"Multiple faces detected ({len(face_locations)}). Please upload an image with only one face.",
                face_count=len(face_locations)
            )
        
        # Get encoding
        encodings = get_face_encodings(img, face_locations)
        
        if len(encodings) == 0:
            return EncodingResponse(
                success=False,
                message="Could not extract face encoding",
                face_count=1
            )
        
        return EncodingResponse(
            success=True,
            message="Face encoding extracted successfully",
            encoding=encodings[0].tolist(),
            face_count=1
        )
        
    except Exception as e:
        logger.error(f"Error encoding face: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/recognize", response_model=RecognitionResponse)
async def recognize_faces(
    image: UploadFile = File(...),
    known_faces: str = Form(...),
    threshold: float = Form(0.75)
):
    """
    Recognize faces in a class photo against known student faces.
    
    Args:
        image: Class photo with multiple students
        known_faces: JSON string of known faces with encodings
        threshold: Confidence threshold (0-1, default 0.75 = 75%)
    """
    start_time = datetime.now()
    
    try:
        # Parse known faces
        known_faces_data = json.loads(known_faces)
        
        if not known_faces_data:
            raise HTTPException(status_code=400, detail="No known faces provided")
        
        # Extract known encodings
        known_encodings = []
        known_info = []
        
        for face in known_faces_data:
            known_encodings.append(np.array(face['encoding']))
            known_info.append({
                'id': face['id'],
                'rollNumber': face['rollNumber'],
                'name': face['name']
            })
        
        # Read and process image
        contents = await image.read()
        img = load_image_from_upload(contents)
        
        # Detect faces
        face_locations = detect_faces(img)
        
        if len(face_locations) == 0:
            processing_time = (datetime.now() - start_time).total_seconds() * 1000
            return RecognitionResponse(
                success=True,
                message="No faces detected in the image",
                total_faces_detected=0,
                recognized=[],
                unrecognized_count=0,
                processing_time_ms=processing_time
            )
        
        # Get encodings for detected faces
        face_encodings = get_face_encodings(img, face_locations)
        
        # Match faces
        recognized = []
        unrecognized_count = 0
        matched_ids = set()  # Prevent duplicate matches
        
        # Convert threshold to tolerance (distance)
        tolerance = 1 - threshold
        
        for i, (face_encoding, location) in enumerate(zip(face_encodings, face_locations)):
            match_index, confidence = compare_faces(known_encodings, face_encoding, tolerance)
            
            if match_index >= 0 and known_info[match_index]['id'] not in matched_ids:
                info = known_info[match_index]
                matched_ids.add(info['id'])
                
                top, right, bottom, left = location
                recognized.append(RecognizedFace(
                    id=info['id'],
                    rollNumber=info['rollNumber'],
                    name=info['name'],
                    confidence=round(confidence, 4),
                    location={
                        'top': top,
                        'right': right,
                        'bottom': bottom,
                        'left': left
                    }
                ))
            else:
                unrecognized_count += 1
        
        processing_time = (datetime.now() - start_time).total_seconds() * 1000
        
        return RecognitionResponse(
            success=True,
            message=f"Recognized {len(recognized)} out of {len(face_locations)} faces",
            total_faces_detected=len(face_locations),
            recognized=recognized,
            unrecognized_count=unrecognized_count,
            processing_time_ms=round(processing_time, 2)
        )
        
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON format for known_faces")
    except Exception as e:
        logger.error(f"Error recognizing faces: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/detect")
async def detect_faces_only(image: UploadFile = File(...)):
    """
    Detect faces in an image without recognition.
    Returns face locations and count.
    """
    try:
        contents = await image.read()
        img = load_image_from_upload(contents)
        
        face_locations = detect_faces(img)
        
        faces = []
        for top, right, bottom, left in face_locations:
            faces.append({
                'location': {
                    'top': top,
                    'right': right,
                    'bottom': bottom,
                    'left': left
                },
                'width': right - left,
                'height': bottom - top
            })
        
        return {
            'success': True,
            'face_count': len(faces),
            'faces': faces
        }
        
    except Exception as e:
        logger.error(f"Error detecting faces: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/compare")
async def compare_two_faces(
    image1: UploadFile = File(...),
    image2: UploadFile = File(...)
):
    """
    Compare two face images to check if they are the same person.
    """
    try:
        # Load images
        contents1 = await image1.read()
        contents2 = await image2.read()
        
        img1 = load_image_from_upload(contents1)
        img2 = load_image_from_upload(contents2)
        
        # Detect and encode faces
        locations1 = detect_faces(img1)
        locations2 = detect_faces(img2)
        
        if len(locations1) == 0:
            return {'success': False, 'message': 'No face detected in first image'}
        if len(locations2) == 0:
            return {'success': False, 'message': 'No face detected in second image'}
        
        encoding1 = get_face_encodings(img1, [locations1[0]])[0]
        encoding2 = get_face_encodings(img2, [locations2[0]])[0]
        
        # Compare
        distance = face_recognition.face_distance([encoding1], encoding2)[0]
        confidence = 1 - distance
        is_same = distance <= 0.6
        
        return {
            'success': True,
            'is_same_person': is_same,
            'confidence': round(confidence, 4),
            'distance': round(distance, 4)
        }
        
    except Exception as e:
        logger.error(f"Error comparing faces: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

