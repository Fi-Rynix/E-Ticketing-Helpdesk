import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/presentation/pages/splash_screen.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/register_screen.dart';
import '../../features/auth/presentation/pages/reset_password_screen.dart';
import '../../features/dashboard/presentation/pages/main_layout.dart';
import '../../features/ticket/presentation/pages/ticket_list_page.dart';
import '../../features/ticket/presentation/pages/ticket_detail_page.dart';
import '../../features/ticket/presentation/pages/create_ticket_page.dart';
import '../../features/ticket/data/models/ticket_model.dart';
import '../../features/notification/presentation/pages/notification_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/user_management/presentation/pages/user_list_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/ticket/presentation/pages/tracking_ticket_page.dart';

/// App Router class to handle all named routes and argument passing
class AppRouter {
  /// Generate routes for the app with support for arguments
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppConstants.routeSplash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      
      case AppConstants.routeLogin:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      
      case AppConstants.routeRegister:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
          settings: settings,
        );
      
      case '/reset_password':
        return MaterialPageRoute(
          builder: (_) => const ResetPasswordScreen(),
          settings: settings,
        );
      
      case AppConstants.routeDashboard:
        return MaterialPageRoute(
          builder: (_) => const MainLayout(),
          settings: settings,
        );
      
      case AppConstants.routeTicketList:
        return MaterialPageRoute(
          builder: (_) => const TicketListPage(),
          settings: settings,
        );
      
      case AppConstants.routeTicketDetail:
        final ticketId = settings.arguments as int;
        return MaterialPageRoute(
          builder: (_) => TicketDetailPage(ticketId: ticketId),
          settings: settings,
        );
      
      case AppConstants.routeCreateTicket:
        return MaterialPageRoute(
          builder: (_) => const CreateTicketPage(),
          settings: settings,
        );

      case AppConstants.routeEditTicket:
        final ticket = settings.arguments as Ticket;
        return MaterialPageRoute(
          builder: (_) => CreateTicketPage(ticket: ticket),
          settings: settings,
        );
      
      case AppConstants.routeNotification:
        return MaterialPageRoute(
          builder: (_) => const NotificationPage(),
          settings: settings,
        );
      
      case '/settings':
        return MaterialPageRoute(
          builder: (_) => const SettingsPage(),
          settings: settings,
        );

      case AppConstants.routeUserManagement:
        return MaterialPageRoute(
          builder: (_) => const UserListPage(),
          settings: settings,
        );

      case AppConstants.routeSettings:
        return MaterialPageRoute(
          builder: (_) => const SettingsPage(),
          settings: settings,
        );

      case AppConstants.routeTrackingTicket:
        final ticket = settings.arguments as Ticket;
        return MaterialPageRoute(
          builder: (_) => TrackingTicketPage(ticket: ticket),
          settings: settings,
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
          settings: settings,
        );
    }
  }

  /// Build initial routes map for MaterialApp
  static Map<String, WidgetBuilder> buildRoutes() {
    return {
      AppConstants.routeSplash: (context) => const SplashScreen(),
      AppConstants.routeLogin: (context) => const LoginScreen(),
      AppConstants.routeRegister: (context) => const RegisterScreen(),
      AppConstants.routeDashboard: (context) => const MainLayout(),
      AppConstants.routeTicketList: (context) => const TicketListPage(),
      AppConstants.routeCreateTicket: (context) => const CreateTicketPage(),
      AppConstants.routeEditTicket: (context) {
        final ticket = ModalRoute.of(context)!.settings.arguments as Ticket;
        return CreateTicketPage(ticket: ticket);
      },
      AppConstants.routeNotification: (context) => const NotificationPage(),
      '/settings': (context) => const SettingsPage(),
      '/reset_password': (context) => const ResetPasswordScreen(),
      AppConstants.routeUserManagement: (context) => const UserListPage(),
      AppConstants.routeSettings: (context) => const SettingsPage(),
      AppConstants.routeTrackingTicket: (context) {
        final ticket = ModalRoute.of(context)!.settings.arguments as Ticket;
        return TrackingTicketPage(ticket: ticket);
      },
    };
  }
}
