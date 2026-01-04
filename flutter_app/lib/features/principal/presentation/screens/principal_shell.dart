import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

class PrincipalShell extends ConsumerStatefulWidget {
  final Widget child;
  
  const PrincipalShell({super.key, required this.child});

  @override
  ConsumerState<PrincipalShell> createState() => _PrincipalShellState();
}

class _PrincipalShellState extends ConsumerState<PrincipalShell> {
  int _currentIndex = 0;

  final _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Teachers',
    ),
    NavigationDestination(
      icon: Icon(Icons.school_outlined),
      selectedIcon: Icon(Icons.school),
      label: 'Students',
    ),
    NavigationDestination(
      icon: Icon(Icons.class_outlined),
      selectedIcon: Icon(Icons.class_),
      label: 'Classes',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _currentIndex = index);
    
    switch (index) {
      case 0:
        context.go('/principal');
        break;
      case 1:
        context.go('/principal/teachers');
        break;
      case 2:
        context.go('/principal/students');
        break;
      case 3:
        context.go('/principal/classes');
        break;
      case 4:
        context.go('/principal/settings');
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
    
    if (location.startsWith('/principal/teachers')) {
      _currentIndex = 1;
    } else if (location.startsWith('/principal/students')) {
      _currentIndex = 2;
    } else if (location.startsWith('/principal/classes')) {
      _currentIndex = 3;
    } else if (location.startsWith('/principal/settings')) {
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

