import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_page.dart';
import 'community_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

// 로그인 화면
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final idController = TextEditingController();
  final pwController = TextEditingController();
  String errorMsg = '';

  Future<void> login() async {
    setState(() {
      errorMsg = '';
    });
    if (idController.text.isEmpty || pwController.text.isEmpty) {
      setState(() {
        errorMsg = 'ID와 비밀번호를 모두 입력하세요.';
      });
      return;
    }
    // 실제 서버 연동
    final url = 'http://127.0.0.1:5000/api/auth/login';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': idController.text,
        'password': pwController.text,
      }),
    );
    if (response.body.isEmpty) {
      setState(() {
        errorMsg = '서버로부터 응답이 없습니다. 네트워크 또는 서버 상태를 확인하세요.';
      });
      return;
    }
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final token = data['access_token'];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage(token: token)),
      );
    } else {
      setState(() {
        errorMsg = '로그인 실패: \n${data['msg'] ?? '서버 오류'}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('로고', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  hintText: 'id',
                  filled: true,
                  fillColor: Color(0xFFF0F0F0),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pwController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'password',
                  filled: true,
                  fillColor: Color(0xFFF0F0F0),
                  border: InputBorder.none,
                ),
              ),
              if (errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(errorMsg, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterPage()),
                  );
                },
                child: const Text('join us', style: TextStyle(decoration: TextDecoration.underline)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: login,
                child: const Text('로그인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 회원가입 화면
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final idController = TextEditingController();
  final pwController = TextEditingController();
  DateTime? selectedDate;
  String? gender;
  Map<String, String> errors = {};

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> register() async {
    setState(() {
      errors = {};
    });
    if (nameController.text.isEmpty) errors['name'] = '사용자 이름을 입력하세요.';
    if (idController.text.isEmpty) errors['id'] = 'ID를 입력하세요.';
    if (pwController.text.isEmpty) errors['pw'] = 'PASSWORD를 입력하세요.';
    if (selectedDate == null) errors['birth'] = '생년월일을 선택하세요.';
    if (gender == null) errors['gender'] = '성별을 선택하세요.';
    if (errors.isNotEmpty) {
      setState(() {});
      return;
    }
    final url = 'http://127.0.0.1:5000/api/auth/register';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': idController.text,
        'password': pwController.text,
        'birth': selectedDate != null ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}' : '',
        'gender': gender,
        'name': nameController.text,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('회원가입 완료'),
          content: const Text('회원가입이 완료되었습니다!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
                Navigator.pop(context); // 회원가입 화면 닫기(로그인 화면으로 이동)
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        errors['server'] = '회원가입 실패: \n${jsonDecode(response.body)['error'] ?? '서버 오류'}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '사용자 이름',
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              if (errors['name'] != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text('• ${errors['name']!}', style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: idController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ID',
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.account_circle),
                ),
              ),
              if (errors['id'] != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text('• ${errors['id']!}', style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: pwController,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'PASSWORD',
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              if (errors['pw'] != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text('• ${errors['pw']!}', style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              const SizedBox(height: 12),
              // 생년월일: DatePicker
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectDate(context),
                      child: Text(selectedDate == null
                          ? '생년월일 선택'
                          : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'),
                    ),
                  ),
                ],
              ),
              if (errors['birth'] != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text('• ${errors['birth']!}', style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              const SizedBox(height: 12),
              // 성별: 라디오 버튼
              Row(
                children: [
                  Radio<String>(
                    value: '남',
                    groupValue: gender,
                    onChanged: (value) {
                      setState(() {
                        gender = value;
                      });
                    },
                  ),
                  const Text('남'),
                  Radio<String>(
                    value: '여',
                    groupValue: gender,
                    onChanged: (value) {
                      setState(() {
                        gender = value;
                      });
                    },
                  ),
                  const Text('여'),
                ],
              ),
              if (errors['gender'] != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text('• ${errors['gender']!}', style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              if (errors['server'] != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text(errors['server']!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (nameController.text.isNotEmpty &&
                    idController.text.isNotEmpty &&
                    pwController.text.isNotEmpty &&
                    selectedDate != null &&
                    gender != null)
                    ? register
                    : null,
                child: const Text('회원가입'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 임시 홈 화면 → 옷장 메인 화면으로 대체
class HomePage extends StatefulWidget {
  final String token;
  const HomePage({super.key, required this.token});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String? _activeFilter;
  Map<String, dynamic>? profileData;
  bool isLoadingProfile = false;
  // 아래는 프로필 관련 더미 데이터 (실제 로그인 정보와 연동 가능)
  int itemCount = 3;
  int likeCount = 50;
  int postCount = 5;
  List<String> styles = ['Active', 'Casual', 'Smart-Casual', 'Formal'];
  List<String> selectedStyles = [];

  @override
  void initState() {
    super.initState();
    _fetchProfileAndSetState();
  }

  Future<void> _fetchProfileAndSetState() async {
    setState(() { isLoadingProfile = true; });
    final url = 'http://127.0.0.1:5000/api/auth/profile';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    };
    print('profile API 호출! token: ${widget.token}');
    print('headers: ' + headers.toString());
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );
    print('statusCode: \'${response.statusCode}\'');
    print('body: ' + response.body);
    if (response.statusCode == 200) {
      setState(() {
        profileData = jsonDecode(response.body);
        isLoadingProfile = false;
      });
    } else {
      setState(() {
        profileData = null;
        isLoadingProfile = false;
      });
    }
  }

  void _onStyleChanged(List<String> newStyles) {
    setState(() {
      selectedStyles = newStyles;
    });
  }

  void _onFilterTap(String filter) {
    setState(() {
      _activeFilter = filter;
    });
    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (filter == 'style') {
          return _buildStyleFilter();
        } else if (filter == 'season') {
          return _buildSeasonFilter();
        } else if (filter == 'color') {
          return _buildColorFilter();
        } else {
          return const SizedBox.shrink();
        }
      },
    ).then((_) {
      setState(() {
        _activeFilter = null;
      });
    });
  }

  Widget _buildStyleFilter() {
    final styles = ['Active', 'Casual', 'Smart-Casual', 'Formal'];
    return _buildFilterSheet('스타일로 필터링', styles);
  }

  Widget _buildSeasonFilter() {
    final seasons = ['Spring', 'Summer', 'Fall', 'Winter'];
    return _buildFilterSheet('계절로 필터링', seasons);
  }

  Widget _buildColorFilter() {
    final colors = ['투명 / 크리스탈', '흰색', '밝은 회색 / 실버', '회색'];
    return _buildFilterSheet('색상으로 필터링', colors);
  }

  Widget _buildFilterSheet(String title, List<String> options) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...options.map((opt) => ListTile(
                title: Text(opt),
                trailing: const Icon(Icons.check, color: Colors.black26),
                onTap: () => Navigator.pop(context),
              )),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('적용'),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: isLoadingProfile
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.account_circle, color: Colors.black),
            onPressed: () {
              if (profileData != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(
                      username: profileData!['username'] ?? '',
                      gender: profileData!['gender'] ?? '',
                      birth: profileData!['birth'] ?? '',
                      itemCount: 0,
                      likeCount: 0,
                      postCount: 0,
                      styles: styles,
                      selectedStyles: selectedStyles,
                      token: widget.token,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('프로필 정보를 불러오지 못했습니다. 다시 시도해 주세요.')),
                );
                _fetchProfileAndSetState();
              }
            },
          ),
        ],
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildFilterButton('전체', null),
            _buildFilterButton('스타일', 'style'),
            _buildFilterButton('색상', 'color'),
            _buildFilterButton('계절', 'season'),
          ],
        ),
        toolbarHeight: 60,
      ),
      body: _selectedIndex == 2
          ? (profileData != null
              ? CommunityPage(token: widget.token, userId: profileData!['id'])
              : const Center(child: CircularProgressIndicator()))
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 48),
                    onPressed: () {
                      // 옷 추가 기능 연결 예정
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text('옷 추가', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.checkroom), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: ''),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String? filterKey) {
    final isActive = _activeFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? Colors.black12 : Colors.white,
          side: const BorderSide(color: Colors.black12),
        ),
        onPressed: filterKey == null ? null : () => _onFilterTap(filterKey),
        child: Text(label, style: const TextStyle(color: Colors.black)),
      ),
    );
  }
} 