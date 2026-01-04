import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

class TeacherShell extends ConsumerStatefulWidget {
  final Widget child;
  
  const TeacherShell({super.key, required this.child});

  @override
  ConsumerState<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends ConsumerState<TeacherShell> {
  int _currentIndex = 0;

  final _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.check_circle_outline),
      selectedIcon: Icon(Icons.check_circle),
      label: 'Attendance',
    ),
    NavigationDestination(
      icon: Icon(Icons.grade_outlined),
      selectedIcon: Icon(Icons.grade),
      label: 'Marks',
    ),
    NavigationDestination(
      icon: Icon(Icons.quiz_outlined),
      selectedIcon: Icon(Icons.quiz),
      label: 'Quizzes',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_outlined),
      selectedIcon: Icon(Icons.chat),
      label: 'AI Chat',
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _currentIndex = index);
    
    switch (index) {
      case 0:
        context.go('/teacher');
        break;
      case 1:
        context.go('/teacher/attendance');
        break;
      case 2:
        context.go('/teacher/marks');
        break;
      case 3:
        context.go('/teacher/quizzes');
        break;
      case 4:
        context.go('/teacher/chat');
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurrentIndex();
  }

  void _updateCurrentIndex() {
    final location = GoRouterState.of(context).uri.path;
    
    if (location.startsWith('/teacher/attendance')) {
      _currentIndex = 1;
    } else if (location.startsWith('/teacher/marks')) {
      _currentIndex = 2;
    } else if (location.startsWith('/teacher/quizzes')) {
      _currentIndex = 3;
    } else if (location.startsWith('/teacher/chat')) {
      _currentIndex = 4;
    } else {
      _currentIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: _destinations,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}

