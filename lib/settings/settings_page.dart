// import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/settings/privacy_policy.dart';
import 'package:nova_videoplayer/settings/terms_and_conditions.dart';
import 'package:nova_videoplayer/settings/app_logs_screen.dart';
import 'package:nova_videoplayer/settings/shorts_settings_screen.dart';

import '../functions/text_class.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: colorBlack,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                      overflow: TextOverflow.ellipsis,
                      fontFamily: 'poppins',
                      color: Colors.white,
                      fontSize: 23),
                ),
                const SizedBox(
                  height: 10,
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutScreen(),
                        ));
                  },
                  child: ListSettings(
                    titleText: TextAllWidget.settingAboutNova,
                    yourIcon: Icons.info_outline,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsAndConditionScreen(),
                        ));
                  },
                  child: ListSettings(
                    titleText: TextAllWidget.settingTermsAndCondition,
                    yourIcon: Icons.gavel_rounded,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ));
                  },
                  child: ListSettings(
                    titleText: TextAllWidget.settingPrivacyPolicy,
                    yourIcon: Icons.privacy_tip_outlined,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ShortsSettingsScreen(),
                        ));
                  },
                  child: ListSettings(
                    titleText: TextAllWidget.settingShorts,
                    yourIcon: Icons.slow_motion_video_rounded,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppLogsScreen(),
                        ));
                  },
                  child: ListSettings(
                    titleText: TextAllWidget.settingAppLogs,
                    yourIcon: Icons.bug_report_outlined,
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}

class ListSettings extends StatelessWidget {
  const ListSettings({
    Key? key,
    required this.titleText,
    required this.yourIcon,
  }) : super(key: key);
  final String titleText;
  final IconData yourIcon;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Colors.black,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(color: colorBlack)),
        child: ListTile(
          iconColor: Colors.white,
          selectedColor: Colors.black,
          leading: Icon(yourIcon),
          title: Text(
            titleText,
            style: const TextStyle(
                overflow: TextOverflow.ellipsis, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
