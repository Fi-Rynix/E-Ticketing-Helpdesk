class AppConstants {
  // App info
  static const String appName = 'E-Ticketing Helpdesk';
  static const String appVersion = '1.0.0';

  // Routes
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeDashboard = '/dashboard';
  static const String routeTicketList = '/tickets';
  static const String routeTicketDetail = '/ticket_detail';
  static const String routeCreateTicket = '/create_ticket';
  static const String routeEditTicket = '/edit_ticket';
  static const String routeUserManagement = '/user_management';
  static const String routeSettings = '/settings';
  static const String routeTrackingTicket = '/tracking_ticket';
  static const String routeNotification = '/notification';

  // Status
  static const String statusOpen = 'open';
  static const String statusAssigned = 'assigned';
  static const String statusInProgress = 'in_progress';
  static const String statusDone = 'done';
  static const String statusCancelled = 'cancelled';

  // Roles
  static const String roleUser = 'user';
  static const String roleAdmin = 'admin';
}
