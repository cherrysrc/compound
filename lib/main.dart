import 'package:easy_localization/easy_localization.dart';
import 'package:fludip/net/savedServers.dart';
import 'package:fludip/pages/login/serverSelectPage.dart';
import 'package:fludip/provider/blubber/blubberProvider.dart';
import 'package:fludip/provider/calendar/calendarProvider.dart';
import 'package:fludip/provider/course/courseProvider.dart';
import 'package:fludip/provider/course/files/fileProvider.dart';
import 'package:fludip/provider/course/forum/forumProvider.dart';
import 'package:fludip/provider/course/members/membersProvider.dart';
import 'package:fludip/provider/course/semester/semesterProvider.dart';
import 'package:fludip/provider/messages/messageProvider.dart';
import 'package:fludip/provider/news/globalNewsProvider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'provider/user/userProvider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });

  await SavedServers().init();

  runApp(EasyLocalization(
    supportedLocales: [Locale("en", "GB"), Locale("de", "DE")],
    path: "assets/translations",
    fallbackLocale: Locale("en", "GB"),
    child: App(),
  ));
}

//TODO darkmode ^^
//TODO user settings:
// 1. custom colors for courses
// 2. (fingerprint?) unlock

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SemesterProvider()),
        ChangeNotifierProvider(create: (_) => NewsProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => ForumProvider()),
        ChangeNotifierProvider(create: (_) => MembersProvider()),
        ChangeNotifierProvider(create: (_) => FileProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => BlubberProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.deviceLocale,
        title: "Fludip",
        home: ServerSelectPage(),
      ),
    );
  }
}
