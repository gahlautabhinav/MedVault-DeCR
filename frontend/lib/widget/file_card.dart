import 'package:flutter/material.dart';

class FileCard extends StatelessWidget {
  final String fileCid;
  final String grantee;
  final String encKeyCid;

  const FileCard({
    super.key,
    required this.fileCid,
    required this.grantee,
    required this.encKeyCid,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file),
        title: Text('File: $fileCid'),
        subtitle: Text('Grantee: $grantee\nKey: $encKeyCid'),
      ),
    );
  }
}
