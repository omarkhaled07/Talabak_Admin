import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  Future<Map<String, dynamic>> _fetchStats() async {
    final orderSnapshot = await FirebaseFirestore.instance.collection('deliveryRequests').get();
    final userSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final restaurantSnapshot = await FirebaseFirestore.instance
        .collection('entities')
        .doc('restaurants')
        .collection('items')
        .get();
    final pharmacySnapshot = await FirebaseFirestore.instance
        .collection('entities')
        .doc('pharmacies')
        .collection('items')
        .get();
    final storeSnapshot = await FirebaseFirestore.instance
        .collection('entities')
        .doc('stores')
        .collection('items')
        .get();
    final grocerySnapshot = await FirebaseFirestore.instance
        .collection('entities')
        .doc('groceryStores')
        .collection('items')
        .get();

    final orderStats = {
      'pending': 0,
      'in_progress': 0,
      'completed': 0,
      'cancelled': 0,
    };

    for (var doc in orderSnapshot.docs) {
      final status = doc['status'] ?? 'pending';
      orderStats[status] = (orderStats[status] ?? 0) + 1;
    }

    return {
      'orders': orderStats,
      'users': userSnapshot.docs.length,
      'restaurants': restaurantSnapshot.docs.length,
      'pharmacies': pharmacySnapshot.docs.length,
      'stores': storeSnapshot.docs.length,
      'groceryStores': grocerySnapshot.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('التقارير', textDirection: TextDirection.rtl, style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xff112b16),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('لا توجد بيانات', textDirection: TextDirection.rtl));
          }

          final stats = snapshot.data!;
          final orderStats = stats['orders'] as Map<String, int>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'إحصائيات عامة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: const Text('عدد المستخدمين', textDirection: TextDirection.rtl),
                    trailing: Text('${stats['users']}', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('عدد المطاعم', textDirection: TextDirection.rtl),
                    trailing: Text('${stats['restaurants']}', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('عدد الصيدليات', textDirection: TextDirection.rtl),
                    trailing: Text('${stats['pharmacies']}', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('عدد المتاجر', textDirection: TextDirection.rtl),
                    trailing: Text('${stats['stores']}', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('عدد البقالات', textDirection: TextDirection.rtl),
                    trailing: Text('${stats['groceryStores']}', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'إحصائيات الطلبات',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: const Text('طلبات قيد الانتظار', textDirection: TextDirection.rtl),
                    trailing: Text('${orderStats['pending']}', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('طلبات قيد التوصيل', textDirection: TextDirection.rtl),
                    trailing: Text('${orderStats['in_progress']}', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('طلبات مكتملة', textDirection: TextDirection.rtl),
                    trailing: Text('${orderStats['completed']}', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('طلبات ملغاة', textDirection: TextDirection.rtl),
                    trailing: Text('${orderStats['cancelled']}', style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}