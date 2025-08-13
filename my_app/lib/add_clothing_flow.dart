import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 1단계: 사진 촬영/선택 화면
class AddClothingStep1 extends StatefulWidget {
  final String token;
  
  const AddClothingStep1({super.key, required this.token});
  
  @override
  State<AddClothingStep1> createState() => _AddClothingStep1State();
}

class _AddClothingStep1State extends State<AddClothingStep1> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      // macOS에서는 카메라 직접 접근이 제한적이므로 갤러리에서 선택하도록 안내
      if (Platform.isMacOS) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('macOS에서는 갤러리에서 사진을 선택해주세요.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // iOS/Android에서만 카메라 사용
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사진이 성공적으로 촬영되었습니다!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      String errorMessage = '사진 촬영 중 오류가 발생했습니다';
      if (e.toString().contains('camera_access_denied')) {
        errorMessage = '카메라 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.';
      } else if (e.toString().contains('camera_not_available')) {
        errorMessage = '카메라를 사용할 수 없습니다.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      if (Platform.isMacOS) {
        // macOS에서는 file_picker 사용
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        
        if (result != null && result.files.single.path != null) {
          setState(() {
            _selectedImage = File(result.files.single.path!);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('사진이 성공적으로 선택되었습니다!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // iOS/Android에서는 image_picker 사용
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        
        if (image != null) {
          setState(() {
            _selectedImage = File(image.path);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('사진이 성공적으로 선택되었습니다!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      String errorMessage = '갤러리에서 선택 중 오류가 발생했습니다: ${e.toString()}';
      if (e.toString().contains('photo_access_denied')) {
        errorMessage = '사진 라이브러리 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '옷 추가',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _selectedImage != null
                  ? Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '사진을 촬영하거나\n갤러리에서 선택하세요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('촬영'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _pickFromGallery,
                                icon: const Icon(Icons.photo_library),
                                label: const Text('갤러리'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[600],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedImage != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddClothingStep2(
                              token: widget.token,
                              selectedImage: _selectedImage!,
                            ),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedImage != null ? Colors.black : Colors.grey[300],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '다음',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 2단계: 카테고리 설정 화면
class AddClothingStep2 extends StatefulWidget {
  final String token;
  final File selectedImage;
  
  const AddClothingStep2({
    super.key,
    required this.token,
    required this.selectedImage,
  });
  
  @override
  State<AddClothingStep2> createState() => _AddClothingStep2State();
}

class _AddClothingStep2State extends State<AddClothingStep2> {
  String? selectedCategory;
  String? selectedSubcategory;
  final TextEditingController brandController = TextEditingController();

  final Map<String, List<String>> categories = {
    '상의': ['티셔츠', '셔츠', '블라우스', '니트', '후드티', '맨투맨'],
    '하의': ['청바지', '슬랙스', '치마', '반바지', '레깅스', '조거팬츠'],
    '아우터': ['자켓', '코트', '패딩', '가디건', '점퍼', '베스트'],
    '신발': ['운동화', '구두', '부츠', '샌들', '슬리퍼', '하이힐'],
    '악세서리': ['모자', '가방', '벨트', '시계', '목걸이', '귀걸이'],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '아이템 카테고리 설정',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '카테고리',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  ...categories.keys.map((category) => 
                    ExpansionTile(
                      title: Text(
                        category,
                        style: TextStyle(
                          fontWeight: selectedCategory == category 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                          color: selectedCategory == category 
                              ? Colors.black 
                              : Colors.grey[700],
                        ),
                      ),
                      trailing: Icon(
                        Icons.keyboard_arrow_right,
                        color: selectedCategory == category 
                            ? Colors.black 
                            : Colors.grey[400],
                      ),
                      onExpansionChanged: (expanded) {
                        if (expanded) {
                          setState(() {
                            selectedCategory = category;
                            selectedSubcategory = null;
                          });
                        }
                      },
                      children: categories[category]!.map((subcategory) =>
                        ListTile(
                          title: Text(subcategory),
                          trailing: selectedSubcategory == subcategory
                              ? const Icon(Icons.check, color: Colors.black)
                              : null,
                          onTap: () {
                            setState(() {
                              selectedSubcategory = subcategory;
                            });
                          },
                        ),
                      ).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '브랜드 (선택사항)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: brandController,
                    decoration: InputDecoration(
                      hintText: '브랜드명을 입력하세요',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: selectedCategory != null && selectedSubcategory != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddClothingStep3(
                              token: widget.token,
                              selectedImage: widget.selectedImage,
                              category: selectedCategory!,
                              subcategory: selectedSubcategory!,
                              brand: brandController.text,
                            ),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedCategory != null && selectedSubcategory != null
                      ? Colors.black 
                      : Colors.grey[300],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '다음',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3단계: 색상 선택 화면
class AddClothingStep3 extends StatefulWidget {
  final String token;
  final File selectedImage;
  final String category;
  final String subcategory;
  final String brand;
  
  const AddClothingStep3({
    super.key,
    required this.token,
    required this.selectedImage,
    required this.category,
    required this.subcategory,
    required this.brand,
  });
  
  @override
  State<AddClothingStep3> createState() => _AddClothingStep3State();
}

class _AddClothingStep3State extends State<AddClothingStep3> {
  String? selectedColor;
  bool isUploading = false;

  final List<Map<String, dynamic>> colors = [
    {'name': '검정', 'color': Colors.black},
    {'name': '흰색', 'color': Colors.white},
    {'name': '회색', 'color': Colors.grey},
    {'name': '빨강', 'color': Colors.red},
    {'name': '파랑', 'color': Colors.blue},
    {'name': '초록', 'color': Colors.green},
    {'name': '노랑', 'color': Colors.yellow},
    {'name': '주황', 'color': Colors.orange},
    {'name': '보라', 'color': Colors.purple},
    {'name': '분홍', 'color': Colors.pink},
    {'name': '갈색', 'color': Colors.brown},
    {'name': '베이지', 'color': const Color(0xFFF5F5DC)},
    {'name': '네이비', 'color': const Color(0xFF000080)},
    {'name': '카키', 'color': const Color(0xFF8B7D3A)},
    {'name': '와인', 'color': const Color(0xFF722F37)},
    {'name': '민트', 'color': const Color(0xFF98FB98)},
  ];

  Future<void> _uploadClothing() async {
    if (selectedColor == null) return;

    setState(() {
      isUploading = true;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:5001/api/wardrobe/items'),
      );

      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.files.add(
        await http.MultipartFile.fromPath('image', widget.selectedImage.path),
      );
      request.fields['name'] = '${widget.subcategory} 아이템';
      request.fields['category'] = widget.category;
      request.fields['subcategory'] = widget.subcategory;
      request.fields['color'] = selectedColor!;
      request.fields['brand'] = widget.brand;

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      print('응답 상태 코드: ${response.statusCode}');
      print('응답 데이터: $responseData');

      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('옷이 성공적으로 추가되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('업로드 실패 - 상태 코드: ${response.statusCode}');
        print('에러 응답: $responseData');
        final data = jsonDecode(responseData);
        throw Exception(data['error'] ?? '업로드 실패');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('업로드 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '색상',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '모든 데이터 입력 후\n내 옷장에 추가 완료',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '색상 / 컬러',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemCount: colors.length,
                itemBuilder: (context, index) {
                  final colorData = colors[index];
                  final isSelected = selectedColor == colorData['name'];
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedColor = colorData['name'];
                      });
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: colorData['color'],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.grey[300]!,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          colorData['name'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: selectedColor != null && !isUploading
                    ? _uploadClothing
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedColor != null && !isUploading
                      ? Colors.black 
                      : Colors.grey[300],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '완료',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
