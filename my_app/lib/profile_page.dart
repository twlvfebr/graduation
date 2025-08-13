import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  final String token;
  final String username;
  final String gender;
  final String birth;
  final int itemCount;
  final int likeCount;
  final int postCount;
  final List<String> styles;
  final List<String> selectedStyles;
  final String? profileImage;

  const ProfilePage({
    Key? key,
    required this.token,
    required this.username,
    required this.gender,
    required this.birth,
    required this.itemCount,
    required this.likeCount,
    required this.postCount,
    required this.styles,
    required this.selectedStyles,
    this.profileImage,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late List<String> selectedStyles;
  bool isSaving = false;
  int postCount = 0;
  int likeCount = 0;
  List<Map<String, dynamic>> wardrobeItems = [];
  bool isLoadingItems = false;

  @override
  void initState() {
    super.initState();
    selectedStyles = List<String>.from(widget.selectedStyles);
    fetchCounts();
    fetchWardrobeItems();
  }

  Future<void> fetchCounts() async {
    // 게시글 개수
    final postRes = await http.get(
      Uri.parse('http://127.0.0.1:5001/api/community/my_post_count'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (postRes.statusCode == 200) {
      final data = jsonDecode(postRes.body);
      setState(() { postCount = data['post_count'] ?? 0; });
    }
    // 좋아요 총합
    final likeRes = await http.get(
      Uri.parse('http://127.0.0.1:5001/api/community/my_like_count'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (likeRes.statusCode == 200) {
      final data = jsonDecode(likeRes.body);
      setState(() { likeCount = data['like_count'] ?? 0; });
    }
  }

  Future<void> fetchWardrobeItems() async {
    setState(() { isLoadingItems = true; });
    try {
      print('옷장 아이템 요청 중... 토큰: ${widget.token.substring(0, 20)}...');
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5001/api/wardrobe/items'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      
      print('옷장 아이템 응답 상태: ${response.statusCode}');
      print('옷장 아이템 응답 데이터: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          wardrobeItems = List<Map<String, dynamic>>.from(data['items'] ?? []);
        });
        print('옷장 아이템 개수: ${wardrobeItems.length}');
      } else {
        print('옷장 아이템 로드 실패 - 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('옷장 아이템 로드 실패: $e');
    } finally {
      setState(() { isLoadingItems = false; });
    }
  }

  Future<void> savePreferredStyles() async {
    setState(() { isSaving = true; });
    final url = 'http://127.0.0.1:5000/api/auth/profile';
    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: jsonEncode({'preferred_styles': selectedStyles}),
    );
    setState(() { isSaving = false; });
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선호 스타일이 저장되었습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 32),
          // 프로필 사진
          CircleAvatar(
            radius: 48,
            backgroundImage: widget.profileImage != null && widget.profileImage!.isNotEmpty
                ? NetworkImage(widget.profileImage!.startsWith('http') ? widget.profileImage! : 'http://127.0.0.1:5000${widget.profileImage!}')
                : const AssetImage('assets/profile_placeholder.png') as ImageProvider,
          ),
          const SizedBox(height: 16),
          // 닉네임
          Text(
            widget.username,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // 성별/생일
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.gender.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.wc, size: 18),
                    const SizedBox(width: 4),
                    Text(widget.gender, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              if (widget.gender.isNotEmpty && widget.birth.isNotEmpty)
                const SizedBox(width: 16),
              if (widget.birth.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.cake, size: 18),
                    const SizedBox(width: 4),
                    Text(widget.birth, style: const TextStyle(fontSize: 16)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 정보수정 버튼
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfilePage(
                    username: widget.username,
                    gender: widget.gender,
                    birth: widget.birth,
                    profileImage: widget.profileImage,
                    token: widget.token,
                  ),
                ),
              );
            },
            child: const Text('내 정보 수정'),
          ),
          const SizedBox(height: 24),
          // 내 아이템/좋아요/게시물 수
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DummyListPage(title: '내 아이템', token: widget.token)));
                },
                child: _InfoBox(title: '내 아이템', value: wardrobeItems.length.toString()),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DummyListPage(title: '좋아요', token: widget.token)));
                },
                child: _InfoBox(title: '좋아요', value: likeCount.toString()),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DummyListPage(title: '게시물', token: widget.token)));
                },
                child: _InfoBox(title: '게시물', value: postCount.toString()),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // 선호 스타일 설정
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⭐ 선호 스타일 설정'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: widget.styles.map((style) {
                    final selected = selectedStyles.contains(style);
                    return FilterChip(
                      label: Text(style),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            selectedStyles.add(style);
                          } else {
                            selectedStyles.remove(style);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : savePreferredStyles,
                    child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('저장'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 내 옷장 아이템들
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '👕 내 옷장',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: fetchWardrobeItems,
                        child: const Text('새로고침'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: isLoadingItems
                        ? const Center(child: CircularProgressIndicator())
                        : wardrobeItems.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.checkroom, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      '등록된 옷이 없습니다.\n메인 화면에서 옷을 추가해보세요!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey, fontSize: 16),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 0.8,
                                ),
                                itemCount: wardrobeItems.length,
                                itemBuilder: (context, index) {
                                  final item = wardrobeItems[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                              color: Colors.grey[200],
                                            ),
                                            child: item['image_path'] != null
                                                ? ClipRRect(
                                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                    child: Image.network(
                                                      'http://127.0.0.1:5001${item['image_path']}',
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return const Icon(Icons.image_not_supported, size: 32, color: Colors.grey);
                                                      },
                                                    ),
                                                  )
                                                : const Icon(Icons.checkroom, size: 32, color: Colors.grey),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'] ?? '이름 없음',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                item['category'] ?? '',
                                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (item['color'] != null && item['color'].isNotEmpty)
                                                Text(
                                                  item['color'],
                                                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;
  const _InfoBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class DummyListPage extends StatefulWidget {
  final String title;
  final String token;
  const DummyListPage({required this.title, required this.token, Key? key}) : super(key: key);
  @override
  State<DummyListPage> createState() => _DummyListPageState();
}

class _DummyListPageState extends State<DummyListPage> {
  List<dynamic> items = [];
  bool isLoading = false;
  int likeCount = 0;

  @override
  void initState() {
    super.initState();
    fetchList();
  }

  Future<void> fetchList() async {
    setState(() { isLoading = true; });
    String url = '';
    if (widget.title == '게시물') {
      url = 'http://127.0.0.1:5000/api/community/my_posts';
    } else if (widget.title == '좋아요') {
      url = 'http://127.0.0.1:5000/api/community/my_like_details';
    } else if (widget.title == '내 아이템') {
      // TODO: 내 아이템 API로 교체
      setState(() { isLoading = false; });
      return;
    } else if (widget.title == '내 댓글') {
      url = 'http://127.0.0.1:5000/api/community/my_comments';
    }
    if (url.isEmpty) return;
    final response = await http.get(Uri.parse(url), headers: {
      'Authorization': 'Bearer ${widget.token}',
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        if (widget.title == '좋아요') {
          items = data['like_details'] ?? [];
          likeCount = data['like_count'] ?? 0;
        } else if (widget.title == '내 댓글') {
          items = data['comments'] ?? [];
        } else {
          items = data['posts'] ?? [];
        }
        isLoading = false;
      });
    } else {
      setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('목록이 없습니다.'))
              : widget.title == '좋아요'
                  ? Column(
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.favorite, color: Colors.black, size: 48),
                            const SizedBox(width: 12),
                            Text('$likeCount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(height: 1, color: Colors.grey[400]),
                        Expanded(
                          child: ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, idx) {
                              final item = items[idx];
                              return Container(
                                color: idx % 2 == 0 ? Colors.grey[200] : Colors.white,
                                child: ListTile(
                                  leading: const Icon(Icons.favorite, color: Colors.red, size: 32),
                                  title: Row(
                                    children: [
                                      Text(
                                        item['liker_username'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text('님이 회원님의 게시글을 좋아합니다'),
                                    ],
                                  ),
                                  trailing: item['post_image'] != null && item['post_image'] != ''
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            item['post_image'].toString().startsWith('http')
                                                ? item['post_image']
                                                : 'http://127.0.0.1:5000/${item['post_image']}',
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        if (widget.title == '내 댓글') {
                          return ListTile(
                            title: Text(item['content'] ?? ''),
                            subtitle: Text('게시글: ${item['post_description'] ?? ''}'),
                            trailing: Text(item['created_at']?.substring(0, 10) ?? ''),
                          );
                        } else {
                          return ListTile(
                            leading: item['image'] != null && item['image'] != ''
                                ? Image.network(
                                    item['image'].toString().startsWith('http')
                                        ? item['image']
                                        : 'http://127.0.0.1:5000/${item['image']}',
                                    width: 56, height: 56, fit: BoxFit.cover)
                                : null,
                            title: Text(item['description'] ?? ''),
                            subtitle: Text(item['created_at']?.substring(0, 10) ?? ''),
                          );
                        }
                      },
                    ),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  final String username;
  final String gender;
  final String birth;
  final String? profileImage;
  final String token;
  const EditProfilePage({required this.username, required this.gender, required this.birth, this.profileImage, required this.token, Key? key}) : super(key: key);
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController nameController;
  late TextEditingController pwController;
  late TextEditingController birthController;
  String genderValue = '';
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.username);
    pwController = TextEditingController();
    birthController = TextEditingController(text: widget.birth);
    genderValue = widget.gender;
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _imageFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _saveProfile() async {
    final trimmedUsername = nameController.text.trim();
    if (trimmedUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력하세요.')));
      return;
    }
    final uri = Uri.parse('http://127.0.0.1:5000/api/auth/profile');
    var request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer ${widget.token}';
    request.fields['username'] = trimmedUsername;
    request.fields['birth'] = birthController.text;
    request.fields['gender'] = genderValue;
    if (_imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('profile_image', _imageFile!.path));
    }
    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      print('서버 응답: $respStr');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필이 수정되었습니다.')));
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('수정 실패: ${response.statusCode}\n$respStr')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('에러: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보 수정')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (widget.profileImage != null && widget.profileImage!.isNotEmpty
                            ? NetworkImage(widget.profileImage!.startsWith('http') ? widget.profileImage! : 'http://127.0.0.1:5000${widget.profileImage!}')
                            : const AssetImage('assets/profile_placeholder.png') as ImageProvider),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person),
                      hintText: '닉네임',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pwController,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock),
                hintText: '비밀번호',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: birthController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.cake),
                hintText: '생년월일 (예: 2000-01-01)',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.wc),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: genderValue.isEmpty ? null : genderValue,
                  hint: const Text('성별'),
                  items: ['남', '여'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) {},
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: _saveProfile,
                  child: const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 