import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({Key? key}) : super(key: key);

  @override
  _AdminOrdersScreenState createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedTimeFilter = 'all';
  int _unreadNotifications = 0;
  bool _isLoadingExport = false;

  // OneSignal configuration
  final String _oneSignalAppId = 'f041fd58-f89d-45d0-9962-bc441311f0ab';
  final String _oneSignalRestApiKey = 'os_v2_app_6ba72whytvc5bglcxrcbgepqvoybnkf7jjrununf6pusq4jo5onhmjdmkfzhziz7hsogvcl2la3ayg5czngphpp3tetst2fhokale6q';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadUnreadNotifications();
    _setupNewOrderListener();
  }

  Future<void> _loadUnreadNotifications() async {
    final snapshot = await _firestore.collection('notifications')
        .where('read', isEqualTo: false)
        .count()
        .get();
    setState(() {
      _unreadNotifications = snapshot.count!;
    });
  }

  void _setupNewOrderListener() {
    _firestore.collection('orders')
        .orderBy('orderTime', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final newOrder = snapshot.docs.first;
        final data = newOrder.data() as Map<String, dynamic>;
        final orderType = _determineOrderType(data);

        _sendNewOrderNotification(
          orderId: newOrder.id,
          userId: data['userId'],
          userName: data['userName'] ?? 'عميل غير معروف',
          orderType: orderType,
        );
      }
    });
  }

  Future<void> _sendNewOrderNotification({
    required String orderId,
    required String userId,
    required String userName,
    required String orderType,
  }) async {
    try {
      // أولاً: إنشاء البيانات بدون FieldValue
      final notificationData = {
        'title': 'طلب جديد تم استلامه',
        'message': 'تم استلام طلب جديد من $userName (${_getOrderTypeText(orderType)})',
        'time': DateTime.now().toString(),
        'isToAll': false,
        'segment': 'admin',
        'read': false,
        'orderId': orderId,
        'type': 'new_order',
        'timestamp': DateTime.now().toIso8601String(), // استخدمنا هذا بدلاً من FieldValue
      };

      // ثانياً: حفظ الإشعار في Firestore مع FieldValue
      await _firestore.collection('notifications').add({
        ...notificationData,
        'createdAt': FieldValue.serverTimestamp(), // أضفها هنا فقط للـ Firestore
      });

      // ثالثاً: إرسال الإشعار عبر OneSignal (بدون FieldValue)
      final headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Basic $_oneSignalRestApiKey',
      };

      final body = {
        'app_id': _oneSignalAppId,
        'headings': {'en': 'طلب جديد', 'ar': 'طلب جديد'},
        'contents': {'en': notificationData['message'], 'ar': notificationData['message']},
        'data': notificationData, // استخدام البيانات بدون FieldValue
        'filters': [
          {"field": "tag", "key": "user_type", "relation": "=", "value": "admin"}
        ],
      };

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        debugPrint('تم إرسال إشعار الطلب الجديد بنجاح');
      } else {
        debugPrint('فشل إرسال الإشعار: ${response.body}');
      }
    } catch (e) {
      debugPrint('خطأ في إرسال إشعار الطلب الجديد: $e');
    }
  }

  String _getOrderTypeText(String orderType) {
    switch (orderType) {
      case 'restaurant': return 'طلب مطعم';
      case 'pharmacy': return 'طلب صيدلية';
      case 'delivery': return 'طلب توصيل';
      default: return 'طلب غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff112b16),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'الكل'),
            Tab(text: 'قيد الانتظار'),
            Tab(text: 'تم التعيين'),
            Tab(text: 'قيد التوصيل'),
            Tab(text: 'مكتمل'),
          ],
        ),
        actions: [
          IconButton(
            icon: badges.Badge(
              showBadge: _unreadNotifications > 0,
              badgeContent: Text(_unreadNotifications.toString(), style: const TextStyle(color: Colors.white)),
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
            onPressed: _showNotificationsPanel,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              if (value == 'advanced_filter') {
                _showAdvancedFilterDialog();
              } else if (value == 'export') {
                _exportOrdersToExcel();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'advanced_filter',
                child: Text('فلترة متقدمة'),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Text('تصدير إلى Excel'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث برقم الطلب أو اسم العميل...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          _buildStatsPanel(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList('all'),
                _buildOrdersList('pending'),
                _buildOrdersList('assigned'),
                _buildOrdersList('in_progress'),
                _buildOrdersList('completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final orders = snapshot.data!.docs;
        int completed = 0;
        int pending = 0;
        int inProgress = 0;
        int cancelled = 0;

        for (var order in orders) {
          final status = order['status'] ?? 'pending';
          switch (status) {
            case 'completed': completed++; break;
            case 'pending': pending++; break;
            case 'in_progress': inProgress++; break;
            case 'cancelled': cancelled++; break;
          }
        }

        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('المكتملة', completed, Colors.green),
                _buildStatItem('قيد الانتظار', pending, Colors.orange),
                _buildStatItem('قيد التوصيل', inProgress, Colors.blue),
                _buildStatItem('ملغاة', cancelled, Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String title, int count, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12)),
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildOrdersList(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredOrdersStream(statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('لا توجد طلبات', ));
        }

        var orders = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final matchesSearch = _searchQuery.isEmpty ||
              doc.id.toLowerCase().contains(_searchQuery) ||
              (data['userName']?.toString().toLowerCase().contains(_searchQuery) ?? false);

          final matchesTimeFilter = _matchesTimeFilter(data['orderTime']?.toDate());

          return matchesSearch && matchesTimeFilter;
        }).toList();

        if (orders.isEmpty) {
          return  Center(child: Text('لا توجد نتائج', ));
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }

  bool _matchesTimeFilter(DateTime? orderDate) {
    if (orderDate == null) return true;
    if (_selectedTimeFilter == 'all') return true;

    final now = DateTime.now();
    switch (_selectedTimeFilter) {
      case 'today':
        return orderDate.year == now.year &&
            orderDate.month == now.month &&
            orderDate.day == now.day;
      case 'week':
        return orderDate.isAfter(now.subtract(const Duration(days: 7)));
      case 'month':
        return orderDate.isAfter(now.subtract(const Duration(days: 30)));
      default:
        return true;
    }
  }

  Widget _buildOrderCard(DocumentSnapshot order) {
    final data = order.data() as Map<String, dynamic>;
    final orderType = _determineOrderType(data);
    final status = data['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: _getOrderTypeIcon(orderType),
        title: Text('طلب #${order.id.substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${data['userName'] ?? 'عميل غير معروف'} - ${_formatTimestamp(data['orderTime'])}'),
            if (data['assignedToName'] != null)
              Text('الموزع: ${data['assignedToName']}'),
            Text(_getStatusText(status),
                style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold)),
          ],
        ),
        children: [
          if (data['deliveryLocation'] != null)
            SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    data['deliveryLocation'].latitude,
                    data['deliveryLocation'].longitude,
                  ),
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId(order.id),
                    position: LatLng(
                      data['deliveryLocation'].latitude,
                      data['deliveryLocation'].longitude,
                    ),
                    infoWindow: InfoWindow(title: 'عنوان التسليم'),
                  ),
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (orderType == 'restaurant') _buildRestaurantOrderDetails(data),
                if (orderType == 'pharmacy') _buildPharmacyOrderDetails(data),
                if (orderType == 'delivery') _buildDeliveryOrderDetails(data),

                const Divider(),
                _buildDetailRow('وقت الإنشاء:', _formatTimestamp(data['orderTime'])),
                if (data['updatedAt'] != null)
                  _buildDetailRow('آخر تحديث:', _formatTimestamp(data['updatedAt'])),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (status != 'assigned' && status != 'completed')
                      ElevatedButton(
                        onPressed: () => _showDeliveryPersonDialog(order.id, data['userId']),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text('تعيين موزع', style: TextStyle(color: Colors.white)),
                      ),
                    _buildStatusDropdown(order.id, status, data['userId']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantOrderDetails(Map<String, dynamic> data) {
    final restaurantInfo = data['restaurantInfo'] ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تفاصيل طلب المطعم:', style: TextStyle(fontWeight: FontWeight.bold)),
        _buildDetailRow('المطعم:', restaurantInfo['restaurantName'] ?? 'غير معروف'),
        _buildDetailRow('العنوان:', restaurantInfo['restaurantAddress']),
        _buildDetailRow('الهاتف:', restaurantInfo['restaurantPhone']),

        const SizedBox(height: 8),
        const Text('الوجبات المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...(data['items'] as List<dynamic>? ?? []).map((item) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${item['quantity']} × ${item['name']} - ${item['price']} ج.م'),
            ),
        ).toList(),

        const SizedBox(height: 8),
        _buildDetailRow('الإجمالي:', '${data['total'] ?? '0'} ج.م'),
        _buildDetailRow('اسم العميل:', data['userName'] ?? 'غير معروف'),
        _buildDetailRow('هاتف العميل:', data['deliveryPhone']),
        _buildDetailRow('عنوان التسليم:', data['deliveryAddress']),
        _buildDetailRow('ملاحظات:', data['notes'] ?? 'لا توجد'),
      ],
    );
  }

  Widget _buildPharmacyOrderDetails(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تفاصيل طلب الصيدلية:', style: TextStyle(fontWeight: FontWeight.bold)),
        _buildDetailRow('الصيدلية:', data['pharmacyName'] ?? 'غير معروف'),

        if (data['prescriptionImageUrl'] != null && data['prescriptionImageUrl'].isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('صورة الوصفة:', style: TextStyle(fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => _openPrescriptionImage(data['prescriptionImageUrl']),
                child: CachedNetworkImage(
                  imageUrl: data['prescriptionImageUrl'],
                  height: 150,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ],
          ),

        const SizedBox(height: 8),
        _buildDetailRow('الإجمالي:', '${data['total'] ?? '0'} ج.م'),
        _buildDetailRow('اسم العميل:', data['userName'] ?? 'غير معروف'),
        _buildDetailRow('هاتف العميل:', data['deliveryPhone']),
        _buildDetailRow('عنوان التسليم:', data['deliveryAddress']),
        _buildDetailRow('ملاحظات:', data['notes'] ?? 'لا توجد'),
      ],
    );
  }

  Widget _buildDeliveryOrderDetails(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تفاصيل طلب التوصيل:', style: TextStyle(fontWeight: FontWeight.bold)),
        _buildDetailRow('مكان الاستلام:', data['pickupAddress'] ?? 'موقع على الخريطة'),
        _buildDetailRow('مكان التسليم:', data['deliveryAddress']),
        _buildDetailRow('قيمة الطلب:', '${data['total'] ?? '0'} ج.م'),
        _buildDetailRow('اسم العميل:', data['userName'] ?? 'غير معروف'),
        _buildDetailRow('هاتف العميل:', data['deliveryPhone']),
        _buildDetailRow('ملاحظات:', data['notes'] ?? 'لا توجد'),
      ],
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value ?? 'غير متوفر', overflow: TextOverflow.ellipsis, maxLines: 3),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredOrdersStream(String statusFilter) {
    if (statusFilter == 'all') {
      return _firestore.collection('orders').orderBy('orderTime', descending: true).snapshots();
    } else {
      return _firestore.collection('orders')
          .where('status', isEqualTo: statusFilter)
          .orderBy('orderTime', descending: true)
          .snapshots();
    }
  }

  String _determineOrderType(Map<String, dynamic> orderData) {
    if (orderData['restaurantInfo'] != null) return 'restaurant';
    if (orderData['pharmacyId'] != null) return 'pharmacy';
    if (orderData['type'] == 'delivery') return 'delivery';
    return 'unknown';
  }

  Widget _getOrderTypeIcon(String orderType) {
    switch (orderType) {
      case 'restaurant': return const Icon(Icons.restaurant, color: Colors.orange);
      case 'pharmacy': return const Icon(Icons.local_pharmacy, color: Colors.green);
      case 'delivery': return const Icon(Icons.delivery_dining, color: Colors.blue);
      default: return const Icon(Icons.shopping_bag, color: Colors.grey);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'assigned': return 'تم التعيين';
      case 'in_progress': return 'قيد التوصيل';
      case 'completed': return 'مكتمل';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'in_progress': return Colors.blue;
      case 'assigned': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'غير معروف';
    return DateFormat('yyyy/MM/dd HH:mm').format(timestamp.toDate());
  }

  Widget _buildStatusDropdown(String orderId, String currentStatus, String userId) {
    return DropdownButton<String>(
      value: currentStatus,
      items: const [
        DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
        DropdownMenuItem(value: 'assigned', child: Text('تم التعيين')),
        DropdownMenuItem(value: 'in_progress', child: Text('قيد التوصيل')),
        DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
        DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
      ],
      onChanged: (value) {
        if (value != null) {
          _updateOrderStatus(orderId, value, userId);
        }
      },
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus, String userId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      String notificationTitle = '';
      String notificationMessage = '';

      switch (newStatus) {
        case 'pending':
          notificationTitle = 'طلبك قيد الانتظار';
          notificationMessage = 'طلبك رقم #${orderId.substring(0, 6)} في انتظار المراجعة';
          break;
        case 'assigned':
          notificationTitle = 'تم تعيين موزع لطلبك';
          notificationMessage = 'طلبك رقم #${orderId.substring(0, 6)} تم تعيين موزع له';
          break;
        case 'in_progress':
          notificationTitle = 'طلبك قيد التوصيل';
          notificationMessage = 'طلبك رقم #${orderId.substring(0, 6)} قيد التوصيل الآن';
          break;
        case 'completed':
          notificationTitle = 'تم تسليم طلبك';
          notificationMessage = 'تم تسليم طلبك رقم #${orderId.substring(0, 6)} بنجاح';
          break;
        case 'cancelled':
          notificationTitle = 'تم إلغاء طلبك';
          notificationMessage = 'تم إلغاء طلبك رقم #${orderId.substring(0, 6)}';
          break;
      }

      if (notificationTitle.isNotEmpty) {
        await _sendOneSignalNotification(
          userId: userId,
          title: notificationTitle,
          message: notificationMessage,
          orderId: orderId,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث حالة الطلب إلى ${_getStatusText(newStatus)}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التحديث: $e')),
      );
    }
  }

  Future<void> _sendOneSignalNotification({
    required String userId,
    required String title,
    required String message,
    String? orderId,
  }) async {
    try {
      // 1. جلب بيانات المستخدم
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        debugPrint('مستند المستخدم غير موجود');
        return;
      }

      // 2. التحقق من وجود playerId
      final playerId = userDoc['oneSignalPlayerId'] as String?;
      if (playerId == null || playerId.isEmpty) {
        debugPrint('معرف اللاعب (playerId) غير متاح للمستخدم: $userId');
        return;
      }

      // 3. إعداد بيانات الإشعار
      final notificationData = {
        'type': 'order_update',
        'order_id': orderId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // 4. إرسال الإشعار
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_oneSignalRestApiKey',
        },
        body: json.encode({
          'app_id': _oneSignalAppId,
          'include_player_ids': [playerId],
          'headings': {'en': title, 'ar': title},
          'contents': {'en': message, 'ar': message},
          'data': notificationData,
        }),
      );

      // 5. معالجة الاستجابة
      if (response.statusCode == 200) {
        debugPrint('تم إرسال الإشعار بنجاح إلى $userId');
      } else {
        debugPrint('فشل إرسال الإشعار: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('حدث خطأ في إرسال الإشعار: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _showDeliveryPersonDialog(String orderId, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختيار موزع', textAlign: TextAlign.center),
        content: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('users')
              .where('role', isEqualTo: 'delivery')
              .where('deliveryStatus', whereIn: ['online', 'busy'])
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('لا يوجد موزعين متاحين حالياً'));
            }

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final person = snapshot.data!.docs[index];
                  final data = person.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.delivery_dining),
                    title: Text(data['name'] ?? 'غير معروف'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['phone'] ?? 'لا يوجد رقم هاتف'),
                        Text('حالة: ${_getDeliveryStatusText(data['deliveryStatus'])}'),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _assignOrderToDelivery(
                        orderId,
                        person.id,
                        data['name'] ?? 'موزع',
                        userId,
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  String _getDeliveryStatusText(String? status) {
    switch (status) {
      case 'online': return 'متصل';
      case 'offline': return 'غير متصل';
      case 'busy': return 'مشغول';
      default: return 'غير معروف';
    }
  }

  Future<void> _assignOrderToDelivery(
      String orderId,
      String deliveryPersonId,
      String deliveryPersonName,
      String userId,
      ) async {
    try {
      await _firestore.collection('users').doc(deliveryPersonId).update({
        'deliveryStatus': 'busy',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('orders').doc(orderId).update({
        'assignedToId': deliveryPersonId,
        'assignedToName': deliveryPersonName,
        'status': 'assigned',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _sendOneSignalNotification(
        userId: userId,
        title: 'تم تعيين موزع لطلبك',
        message: 'تم تعيين $deliveryPersonName لتوصيل طلبك رقم #${orderId.substring(0, 6)}',
        orderId: orderId,
      );

      await _sendOneSignalNotification(
        userId: deliveryPersonId,
        title: 'تم تعيين طلب جديد لك',
        message: 'تم تعيين طلب رقم #${orderId.substring(0, 6)} لك',
        orderId: orderId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تعيين الطلب إلى $deliveryPersonName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التعيين: $e')),
      );
    }
  }

  Future<void> _openPrescriptionImage(String imageUrl) async {
    try {
      if (await canLaunchUrl(Uri.parse(imageUrl))) {
        await launchUrl(Uri.parse(imageUrl), mode: LaunchMode.externalApplication);
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: imageUrl),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    }
  }

  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإشعارات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: _markAllAsRead,
                  child: const Text('تمييز الكل كمقروء'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final notification = snapshot.data!.docs[index];
                      final data = notification.data() as Map<String, dynamic>;

                      // معالجة حقل timestamp بشكل صحيح
                      DateTime? timestamp;
                      if (data['timestamp'] is Timestamp) {
                        timestamp = (data['timestamp'] as Timestamp).toDate();
                      } else if (data['timestamp'] is String) {
                        timestamp = DateTime.tryParse(data['timestamp']);
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: data['read'] == true ? Colors.white : Colors.grey[100],
                        child: ListTile(
                          title: Text(data['title'] ?? 'إشعار'),
                          subtitle: Text(data['message'] ?? ''),
                          trailing: Text(
                            timestamp != null
                                ? DateFormat('HH:mm').format(timestamp)
                                : '--:--',
                          ),
                          onTap: () => _markNotificationAsRead(notification.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _loadUnreadNotifications());
  }

  Future<void> _markAllAsRead() async {
    final batch = _firestore.batch();
    final notifications = await _firestore.collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
    _loadUnreadNotifications();
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
    _loadUnreadNotifications();
  }

  void _showAdvancedFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة الطلبات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedTimeFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('الكل')),
                DropdownMenuItem(value: 'today', child: Text('اليوم')),
                DropdownMenuItem(value: 'week', child: Text('أسبوع')),
                DropdownMenuItem(value: 'month', child: Text('شهر')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedTimeFilter = value ?? 'all';
                });
                Navigator.pop(context);
              },
              decoration: const InputDecoration(labelText: 'الفترة الزمنية'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportOrdersToExcel() async {
    setState(() => _isLoadingExport = true);

    try {
      final workbook = xlsio.Workbook();
      final worksheet = workbook.worksheets[0];

      // Add headers
      worksheet.getRangeByIndex(1, 1).setText('رقم الطلب');
      worksheet.getRangeByIndex(1, 2).setText('نوع الطلب');
      worksheet.getRangeByIndex(1, 3).setText('اسم العميل');
      worksheet.getRangeByIndex(1, 4).setText('الهاتف');
      worksheet.getRangeByIndex(1, 5).setText('العنوان');
      worksheet.getRangeByIndex(1, 6).setText('القيمة');
      worksheet.getRangeByIndex(1, 7).setText('الحالة');
      worksheet.getRangeByIndex(1, 8).setText('تاريخ الطلب');

      // Get orders data
      final orders = await _firestore.collection('orders')
          .orderBy('orderTime', descending: true)
          .get();

      // Add data rows
      for (int i = 0; i < orders.docs.length; i++) {
        final order = orders.docs[i];
        final data = order.data();

        worksheet.getRangeByIndex(i + 2, 1).setText(order.id.substring(0, 6));
        worksheet.getRangeByIndex(i + 2, 2).setText(_determineOrderType(data));
        worksheet.getRangeByIndex(i + 2, 3).setText(data['userName'] ?? 'غير معروف');
        worksheet.getRangeByIndex(i + 2, 4).setText(data['deliveryPhone'] ?? '');
        worksheet.getRangeByIndex(i + 2, 5).setText(data['deliveryAddress'] ?? '');
        worksheet.getRangeByIndex(i + 2, 6).setNumber(data['total'] ?? 0);
        worksheet.getRangeByIndex(i + 2, 7).setText(_getStatusText(data['status'] ?? 'pending'));
        worksheet.getRangeByIndex(i + 2, 8).setText(_formatTimestamp(data['orderTime']));
      }

      // Save the workbook
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/orders_export.xlsx';
      final File file = File(path);
      await file.writeAsBytes(workbook.saveAsStream());
      workbook.dispose();

      // Open the file
      await OpenFile.open(path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير البيانات بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')),
      );
    } finally {
      setState(() => _isLoadingExport = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}