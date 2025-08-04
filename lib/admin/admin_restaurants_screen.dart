import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_add_restaurant_screen.dart';
import 'admin_categories_screen.dart';

class AdminRestaurantsScreen extends StatelessWidget {
  const AdminRestaurantsScreen({Key? key}) : super(key: key);

  Future<void> _deleteRestaurant(String id) async {
    await FirebaseFirestore.instance
        .collection('entities')
        .doc('restaurants')
        .collection('items')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة المطاعم',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xff112b16),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminAddRestaurantScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('entities')
                .doc('restaurants')
                .collection('items')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد مطاعم'));
          }

          final restaurants = snapshot.data!.docs;

          return ListView.builder(
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final restaurant =
                  restaurants[index].data() as Map<String, dynamic>;
              return _buildRestaurantItem(
                context,
                restaurants[index].id,
                restaurant,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRestaurantItem(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    return ListTile(
      leading: Image.network(
        data['imageUrl'] ?? 'https://via.placeholder.com/60',
        width: 50,
        height: 50,
        errorBuilder:
            (context, error, stackTrace) => const Icon(Icons.restaurant),
      ),
      title: Text(data['name'] ?? 'غير معروف'),
      subtitle: Text(data['deliveryTime'] ?? 'غير متوفر'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => AdminAddRestaurantScreen(
                        restaurantId: id,
                        initialData: data,
                      ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteRestaurant(id),
          ),
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => AdminCategoriesScreen(
                        entityId: id,
                        entityName: data['name'] ?? 'غير معروف',
                        entityCollection: 'restaurants',
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
