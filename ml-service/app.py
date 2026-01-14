from flask import Flask, request, jsonify
from flask_cors import CORS
import face_recognition
import numpy as np
import cv2
import base64
import io
from PIL import Image
import logging

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def decode_base64_image(base64_string):
    """Decode base64 image to numpy array"""
    try:
        # Remove header if present
        if ',' in base64_string:
            base64_string = base64_string.split(',')[1]
        
        image_data = base64.b64decode(base64_string)
        image = Image.open(io.BytesIO(image_data))
        return np.array(image)
    except Exception as e:
        logger.error(f"Error decoding image: {str(e)}")
        return None

def load_image_from_file(file):
    """Load image from uploaded file"""
    try:
        image = Image.open(file.stream)
        return np.array(image)
    except Exception as e:
        logger.error(f"Error loading image: {str(e)}")
        return None

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'face-recognition-ml',
        'version': '1.0.0'
    })

@app.route('/generate-encoding', methods=['POST'])
def generate_encoding():
    """
    Generate face encoding from a single photo
    Expects: multipart/form-data with 'photo' file
    Returns: face encoding as array
    """
    try:
        if 'photo' not in request.files:
            return jsonify({'error': 'No photo provided'}), 400
        
        file = request.files['photo']
        image = load_image_from_file(file)
        
        if image is None:
            return jsonify({'error': 'Invalid image file'}), 400
        
        # Convert to RGB if needed
        if len(image.shape) == 2:  # Grayscale
            image = cv2.cvtColor(image, cv2.COLOR_GRAY2RGB)
        elif image.shape[2] == 4:  # RGBA
            image = cv2.cvtColor(image, cv2.COLOR_RGBA2RGB)
        
        # Detect faces
        face_locations = face_recognition.face_locations(image)
        
        if len(face_locations) == 0:
            return jsonify({'error': 'No face detected in image'}), 400
        
        if len(face_locations) > 1:
            return jsonify({'error': 'Multiple faces detected. Please use a photo with only one face'}), 400
        
        # Generate encoding
        face_encodings = face_recognition.face_encodings(image, face_locations)
        
        if len(face_encodings) == 0:
            return jsonify({'error': 'Could not generate face encoding'}), 400
        
        encoding = face_encodings[0]
        
        return jsonify({
            'success': True,
            'encoding': encoding.tolist(),
            'face_location': {
                'top': face_locations[0][0],
                'right': face_locations[0][1],
                'bottom': face_locations[0][2],
                'left': face_locations[0][3]
            }
        })
    
    except Exception as e:
        logger.error(f"Error generating encoding: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/detect-faces', methods=['POST'])
def detect_faces():
    """
    Detect all faces in a group photo
    Expects: multipart/form-data with 'photo' file
    Returns: list of face encodings and locations
    """
    try:
        if 'photo' not in request.files:
            return jsonify({'error': 'No photo provided'}), 400
        
        file = request.files['photo']
        image = load_image_from_file(file)
        
        if image is None:
            return jsonify({'error': 'Invalid image file'}), 400
        
        # Convert to RGB if needed
        if len(image.shape) == 2:
            image = cv2.cvtColor(image, cv2.COLOR_GRAY2RGB)
        elif image.shape[2] == 4:
            image = cv2.cvtColor(image, cv2.COLOR_RGBA2RGB)
        
        # Detect faces
        face_locations = face_recognition.face_locations(image, model='hog')
        
        if len(face_locations) == 0:
            return jsonify({
                'success': True,
                'faces': [],
                'count': 0
            })
        
        # Generate encodings
        face_encodings = face_recognition.face_encodings(image, face_locations)
        
        faces = []
        for i, (encoding, location) in enumerate(zip(face_encodings, face_locations)):
            faces.append({
                'id': i,
                'encoding': encoding.tolist(),
                'location': {
                    'top': location[0],
                    'right': location[1],
                    'bottom': location[2],
                    'left': location[3]
                }
            })
        
        return jsonify({
            'success': True,
            'faces': faces,
            'count': len(faces)
        })
    
    except Exception as e:
        logger.error(f"Error detecting faces: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/match-faces', methods=['POST'])
def match_faces():
    """
    Match detected faces with reference encodings
    Expects JSON: {
        'detected': [[encoding1], [encoding2], ...],
        'references': {
            'studentId1': [encoding],
            'studentId2': [encoding],
            ...
        },
        'tolerance': 0.6 (optional, default 0.6)
    }
    Returns: list of matches with student IDs and confidence scores
    """
    try:
        data = request.get_json()
        
        if not data or 'detected' not in data or 'references' not in data:
            return jsonify({'error': 'Missing required data'}), 400
        
        detected_encodings = [np.array(enc) for enc in data['detected']]
        reference_encodings = {
            student_id: np.array(enc) 
            for student_id, enc in data['references'].items()
        }
        tolerance = data.get('tolerance', 0.6)
        
        matches = []
        
        for i, detected_encoding in enumerate(detected_encodings):
            best_match = None
            best_distance = float('inf')
            
            for student_id, reference_encoding in reference_encodings.items():
                # Calculate face distance
                distance = face_recognition.face_distance([reference_encoding], detected_encoding)[0]
                
                if distance < tolerance and distance < best_distance:
                    best_distance = distance
                    best_match = student_id
            
            if best_match:
                confidence = 1 - best_distance  # Convert distance to confidence
                matches.append({
                    'faceId': i,
                    'studentId': best_match,
                    'confidence': float(confidence),
                    'distance': float(best_distance)
                })
        
        return jsonify({
            'success': True,
            'matches': matches,
            'totalDetected': len(detected_encodings),
            'totalMatched': len(matches)
        })
    
    except Exception as e:
        logger.error(f"Error matching faces: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/process-attendance', methods=['POST'])
def process_attendance():
    """
    Complete attendance processing pipeline
    Expects: multipart/form-data with multiple 'photos' and JSON 'students' data
    Returns: attendance results with matched students
    """
    try:
        # Get photos
        photos = request.files.getlist('photos')
        if not photos:
            return jsonify({'error': 'No photos provided'}), 400
        
        # Get student reference data
        students_json = request.form.get('students')
        if not students_json:
            return jsonify({'error': 'No student data provided'}), 400
        
        import json
        students = json.loads(students_json)
        
        # Collect all detected faces from all photos
        all_detected_faces = []
        
        for photo in photos:
            image = load_image_from_file(photo)
            if image is None:
                continue
            
            # Convert to RGB
            if len(image.shape) == 2:
                image = cv2.cvtColor(image, cv2.COLOR_GRAY2RGB)
            elif image.shape[2] == 4:
                image = cv2.cvtColor(image, cv2.COLOR_RGBA2RGB)
            
            # Detect faces
            face_locations = face_recognition.face_locations(image, model='hog')
            if len(face_locations) > 0:
                face_encodings = face_recognition.face_encodings(image, face_locations)
                all_detected_faces.extend(face_encodings)
        
        if len(all_detected_faces) == 0:
            return jsonify({
                'success': True,
                'message': 'No faces detected in photos',
                'results': []
            })
        
        # Match with student references
        results = []
        matched_students = set()
        
        for student in students:
            student_id = student['id']
            if not student.get('faceEncoding'):
                results.append({
                    'studentId': student_id,
                    'name': student['name'],
                    'rollNumber': student['rollNumber'],
                    'detected': False,
                    'confidence': 0,
                    'status': 'ABSENT',
                    'reason': 'No reference photo'
                })
                continue
            
            reference_encoding = np.array(student['faceEncoding'])
            
            # Check against all detected faces
            best_match = False
            best_confidence = 0
            
            for detected_encoding in all_detected_faces:
                distance = face_recognition.face_distance([reference_encoding], detected_encoding)[0]
                confidence = 1 - distance
                
                if distance < 0.6 and confidence > best_confidence:
                    best_match = True
                    best_confidence = confidence
            
            if best_match:
                matched_students.add(student_id)
                results.append({
                    'studentId': student_id,
                    'name': student['name'],
                    'rollNumber': student['rollNumber'],
                    'detected': True,
                    'confidence': float(best_confidence),
                    'status': 'PRESENT'
                })
            else:
                results.append({
                    'studentId': student_id,
                    'name': student['name'],
                    'rollNumber': student['rollNumber'],
                    'detected': False,
                    'confidence': 0,
                    'status': 'ABSENT'
                })
        
        return jsonify({
            'success': True,
            'results': results,
            'totalStudents': len(students),
            'totalDetected': len(all_detected_faces),
            'totalMatched': len(matched_students)
        })
    
    except Exception as e:
        logger.error(f"Error processing attendance: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
