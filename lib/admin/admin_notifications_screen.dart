import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'dart:convert';


class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  bool _isSendingToAll = true;
  String? _selectedSegment;

  // أقسام الإشعارات (للتجار، للعملاء، للكل)
  final List<String> _segments = ['all', 'customers', 'merchants'];
  String oneSignalAppId = 'f041fd58-f89d-45d0-9962-bc441311f0ab';
  String oneSignalRestApiKey = 'os_v2_app_6ba72whytvc5bglcxrcbgepqvoybnkf7jjrununf6pusq4jo5onhmjdmkfzhziz7hsogvcl2la3ayg5czngphpp3tetst2fhokale6q'; // Keep this secure!


  Future<void> _sendOneSignalNotification(Map<String, dynamic> notificationData) async {
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Basic $oneSignalRestApiKey',
    };

    final body = {
      'app_id': oneSignalAppId,
      'headings': {'en': 'Talabak Express'},
      'contents': {'en': notificationData['message']},
      'data': {
        'time': notificationData['time'],
        'type': 'admin_notification',
      },
      // Target users
      if (_isSendingToAll)
        'included_segments': ['All']
      else if (_selectedSegment != null)
        'filters': [
          {"field": "tag", "key": "user_type", "relation": "=", "value": _selectedSegment}
        ]
    };

    final response = await post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully: ${response.body}');
    } else {
      print('Failed to send notification: ${response.body}');
      throw Exception('Notification sending failed');
    }
  }

  void _showAddNotificationDialog({DocumentSnapshot? notification}) {
    if (notification != null) {
      _titleController.text = notification['title'] ?? '';
      _messageController.text = notification['message'] ?? '';
      _timeController.text = notification['time'] ?? '';
      _isSendingToAll = notification['isToAll'] ?? true;
      _selectedSegment = notification['segment'];
    } else {
      _titleController.clear();
      _messageController.clear();
      _timeController.clear();
      _isSendingToAll = true;
      _selectedSegment = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            notification == null ? 'إرسال إشعار جديد' : 'تعديل الإشعار',
            textDirection: TextDirection.rtl,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الإشعار',
                    hintTextDirection: TextDirection.rtl,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'نص الإشعار',
                    hintTextDirection: TextDirection.rtl,
                  ),
                  textDirection: TextDirection.rtl,
                  maxLines: 3,
                ),
                TextField(
                  controller: _timeController,
                  decoration: const InputDecoration(
                    labelText: 'وقت الإشعار (اختياري)',
                    hintTextDirection: TextDirection.rtl,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                const Text('إرسال إلى:', textDirection: TextDirection.rtl),
                SwitchListTile(
                  title: const Text('جميع المستخدمين', textDirection: TextDirection.rtl),
                  value: _isSendingToAll,
                  onChanged: (value) {
                    setState(() {
                      _isSendingToAll = value;
                    });
                  },
                ),
                if (!_isSendingToAll) ...[
                  const SizedBox(height: 8),
                  const Text('اختيار شريحة معينة:', textDirection: TextDirection.rtl),
                  Wrap(
                    spacing: 8,
                    children: _segments.map((segment) {
                      return ChoiceChip(
                        label: Text(
                          segment == 'all' ? 'الكل' :
                          segment == 'customers' ? 'العملاء' : 'التجار',
                          textDirection: TextDirection.rtl,
                        ),
                        selected: _selectedSegment == segment,
                        onSelected: (selected) {
                          setState(() {
                            _selectedSegment = selected ? segment : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى إدخال عنوان ونص الإشعار', textDirection: TextDirection.rtl),
                    ),
                  );
                  return;
                }

                final notificationData = {
                  'title': _titleController.text,
                  'message': _messageController.text,
                  'time': _timeController.text.isEmpty
                      ? DateTime.now().toString()
                      : _timeController.text,
                  'isToAll': _isSendingToAll,
                  'segment': _selectedSegment,
                  'createdAt': FieldValue.serverTimestamp(),
                };

                try {
                  // حفظ الإشعار في Firestore
                  if (notification == null) {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .add(notificationData);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(notification.id)
                        .update(notificationData);
                  }

                  // إرسال الإشعار عبر OneSignal
                  await _sendOneSignalNotification(notificationData);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إرسال الإشعار بنجاح', textDirection: TextDirection.rtl),
                    ),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ: $e', textDirection: TextDirection.rtl),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('إرسال', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('إدارة الإشعارات', textDirection: TextDirection.rtl, style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xff112b16),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddNotificationDialog(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('لا توجد إشعارات مرسلة', textDirection: TextDirection.rtl),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final data = notification.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text(data['title'] ?? 'بدون عنوان', textDirection: TextDirection.rtl),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(data['message'] ?? 'بدون محتوى', textDirection: TextDirection.rtl),
                      const SizedBox(height: 4),
                      Text(
                        data['isToAll'] == true
                            ? 'مرسل إلى: الجميع'
                            : 'مرسل إلى: ${data['segment'] == 'customers' ? 'العملاء' : 'التجار'}',
                        style: const TextStyle(fontSize: 12),
                        textDirection: TextDirection.rtl,
                      ),
                      Text(
                        data['time'] ?? 'بدون وقت محدد',
                        style: const TextStyle(fontSize: 12),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAddNotificationDialog(notification: notification),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('notifications')
                              .doc(notification.id)
                              .delete();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _timeController.dispose();
    super.dispose();
  }
}