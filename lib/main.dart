import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/auth_service.dart';
import 'services/favorites_service.dart';
import 'services/web_data_fetcher.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final authService = AuthService();
  final favoritesService = FavoritesService();
  await authService.init();
  await favoritesService.init();

  // 预初始化后台 WebView 拉真实数据
  WebDataFetcher().initController();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: favoritesService),
        ChangeNotifierProvider.value(value: WebDataFetcher()),
      ],
      child: const StripChatApp(),
    ),
  );
}

class StripChatApp extends StatelessWidget {
  const StripChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFF4081),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF4081),
          secondary: Color(0xFFFF6EC7),
          surface: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A1A2E),
          selectedItemColor: Color(0xFFFF4081),
          unselectedItemColor: Colors.grey,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const HomePage(),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            // 不可见的后台 WebView：维持 stripchat session、拉真实数据
            Positioned(
              left: -2000,
              top: -2000,
              width: 1,
              height: 1,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: WebViewWidget(
                    controller: WebDataFetcher().initController(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
