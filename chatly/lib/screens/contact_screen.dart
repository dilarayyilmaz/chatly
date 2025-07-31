import 'package:chatly/models/user_model.dart';
import 'package:chatly/screens/friend_request_screen.dart';
import 'package:chatly/services/friendship_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  String query = '';
  List<UserModel> allContacts = [];
  List<UserModel> filteredContacts = [];
  Map<String, String> friendshipStatus =
      {}; // 🔹 Arkadaşlık durumlarını takip et
  final friendshipService = FriendshipService();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() async {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUid == null) return;

    try {
      // 1️⃣ Önce kullanıcıları hızlıca yükle ve göster
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final contacts = snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .where(
            (user) => user.uid != currentUserUid,
          ) // Sadece kendimizi filtrele
          .toList();

      // Kullanıcıları hemen göster (butonlar Add olarak)
      setState(() {
        allContacts = contacts;
        filteredContacts = List.from(allContacts);
        // Başlangıçta hepsi 'none' olarak ayarla
        friendshipStatus = {for (var user in contacts) user.uid: 'none'};
      });

      // 2️⃣ Sonra arkadaşlık durumlarını arka planda yükle
      await _loadFriendshipStatuses(currentUserUid, contacts);
    } catch (e) {
      print('Error loading contacts: $e');
    }
  }

  // 🚀 Performans optimizasyonu: Tek sorguda tüm durumları al
  Future<void> _loadFriendshipStatuses(
    String currentUserUid,
    List<UserModel> contacts,
  ) async {
    try {
      // Tüm friendships'leri tek sorguda al
      final friendshipsQuery = await FirebaseFirestore.instance
          .collection('friendships')
          .where('memberIds', arrayContains: currentUserUid)
          .get();

      Map<String, String> statusMap = {
        for (var user in contacts) user.uid: 'none',
      };

      // Her friendship kaydını kontrol et
      for (var doc in friendshipsQuery.docs) {
        final data = doc.data();
        List<dynamic> memberIds = data['memberIds'];
        String status = data['status'];
        String requesterId = data['requesterId'];

        // Bu kullanıcının friendships'lerinden hangisi contact listesinde var?
        for (String memberId in memberIds) {
          if (memberId != currentUserUid && statusMap.containsKey(memberId)) {
            if (status == 'accepted') {
              statusMap[memberId] = 'friends';
            } else if (status == 'pending') {
              if (requesterId == currentUserUid) {
                statusMap[memberId] = 'sent';
              } else {
                statusMap[memberId] = 'received';
              }
            }
          }
        }
      }

      // UI'yi güncelle
      setState(() {
        friendshipStatus = statusMap;
      });
    } catch (e) {
      print('Error loading friendship statuses: $e');
    }
  }

  void _filterContacts(String input) {
    setState(() {
      query = input;
      if (input.isEmpty) {
        filteredContacts = List.from(allContacts);
      } else {
        filteredContacts = allContacts
            .where(
              (user) =>
                  user.username!.toLowerCase().contains(input.toLowerCase()),
            )
            .toList();
      }
    });
  }

  void _cancelFriendRequest(UserModel user) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // FriendshipService'de cancelFriendRequest metodu yoksa, declineFriendRequest kullan
      await friendshipService.declineFriendRequest(
        currentUser.uid, // requesterId (ben göndermiştim)
        user.uid, // receiverId
      );

      setState(() {
        friendshipStatus[user.uid] = 'none';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request canceled to ${user.username}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel request: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 🔹 Buton durumunu ve metnini belirle
  Widget _buildActionButton(UserModel user) {
    final status = friendshipStatus[user.uid] ?? 'none';

    switch (status) {
      case 'sent':
        return ElevatedButton(
          onPressed: () => _cancelFriendRequest(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        );

      case 'received':
        // 🔹 Gelen isteklerde kullanıcıyı direkt yönlendir
        return ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FriendRequestScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'View Request',
            style: TextStyle(color: Colors.white),
          ),
        );

      case 'friends':
        // Bu durum artık UI'da görünmeyecek çünkü filtreliyoruz
        return ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Friends', style: TextStyle(color: Colors.white)),
        );

      case 'none':
      default:
        return ElevatedButton(
          onPressed: () => _sendFriendRequest(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F4156),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        );
    }
  }

  // 🔹 Arkadaşlık isteği gönder
  void _sendFriendRequest(UserModel user) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await friendshipService.sendFriendRequest(
        requesterId: currentUser.uid,
        receiverId: user.uid,
      );

      // UI'de güncelle
      setState(() {
        friendshipStatus[user.uid] = 'sent';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to ${user.username}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send request: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 20,
              ),
              child: Row(
                children: [
                  Text(
                    'Add new contact',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                onChanged: _filterContacts,
                decoration: InputDecoration(
                  hintText: 'Search contact',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: cs.surfaceVariant,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: cs.primary),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cs.primary, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            // "Requests" link
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FriendRequestScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Requests',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contact list
            Expanded(
              child: filteredContacts.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2F4156),
                      ),
                    )
                  : (() {
                      // ✅ Sadece arkadaş olmayanları göster
                      final visibleContacts = filteredContacts
                          .where(
                            (user) => friendshipStatus[user.uid] != 'friends',
                          )
                          .toList();

                      if (visibleContacts.isEmpty) {
                        return const Center(
                          child: Text(
                            'All users are already your friends! 🎉',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: visibleContacts.length,
                        itemBuilder: (context, index) {
                          final UserModel user = visibleContacts[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFF2F4156),
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(user.username!),
                            trailing: _buildActionButton(user),
                          );
                        },
                      );
                    })(),
            ),
          ],
        ),
      ),
    );
  }
}
