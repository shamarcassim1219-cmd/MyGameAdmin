import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:open_filex/open_filex.dart';
import '../main.dart';

class UpdateService {
  static const String versionCheckUrl = 'https://api.finbassshamar.online/admin-app-version';

  /// silent: true = only show something when an update IS available (used
  /// for an automatic check on launch). false = also tells the user when
  /// they're already on the latest version (used for a manual "Check for
  /// Updates" button).
  static Future<void> checkForUpdate(BuildContext context, {bool silent = true}) async {
    try {
      final response = await http.get(Uri.parse(versionCheckUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        if (!silent && context.mounted) _showError(context, 'Could not check for updates. Try again later.');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersionCode = data['latestVersionCode'] as int;
      final latestVersion = data['latestVersion']?.toString() ?? '';
      final apkUrl = data['apkUrl'] as String;
      final forceUpdate = data['forceUpdate'] as bool? ?? false;
      final notes = data['updateNotes']?.toString() ?? '';

      final info = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(info.buildNumber);

      if (currentVersionCode < latestVersionCode) {
        if (context.mounted) _showUpdateDialog(context, latestVersion, apkUrl, forceUpdate, notes);
      } else if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're on the latest version")),
        );
      }
    } catch (e) {
      if (!silent && context.mounted) _showError(context, 'Could not check for updates. Check your connection.');
    }
  }

  static void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static void _showUpdateDialog(BuildContext context, String latestVersion, String apkUrl, bool forceUpdate, String notes) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Update Available (v$latestVersion)', style: const TextStyle(color: Colors.white)),
          content: Text(
            notes.isEmpty ? 'A new version of the admin app is available.' : notes,
            style: const TextStyle(color: AppColors.hint),
          ),
          actions: [
            if (!forceUpdate)
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _downloadAndInstall(context, apkUrl);
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _downloadAndInstall(BuildContext context, String apkUrl) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        content: Row(children: const [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(width: 16),
          Text('Downloading update...', style: TextStyle(color: Colors.white)),
        ]),
      ),
    );

    final task = DownloadTask(
      url: apkUrl,
      filename: 'mygame_admin_update.apk',
      baseDirectory: BaseDirectory.applicationSupport,
    );

    final result = await FileDownloader().download(task);
    if (context.mounted) Navigator.pop(context);

    if (result.status == TaskStatus.complete) {
      final filePath = await task.filePath();
      await OpenFilex.open(filePath);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download failed, please try again')),
      );
    }
  }
}
