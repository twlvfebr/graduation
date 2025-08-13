import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Added for jsonDecode
import 'package:flutter/gestures.dart';

class CommunityPage extends StatefulWidget {
  final String token;
  final int userId; // userId 추가
  const CommunityPage({Key? key, required this.token, required this.userId}) : super(key: key);
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> posts = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts({String? query}) async {
    setState(() { isLoading = true; });
    String url = 'http://127.0.0.1:5000/api/community/posts';
    if (query != null && query.trim().isNotEmpty) {
      url += '?query=${Uri.encodeComponent(query.trim())}';
    }
    final uri = Uri.parse(url);
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer ${widget.token}',
    });
    if (response.statusCode == 200) {
      final data = response.body;
      final decoded = data.isNotEmpty ? Map<String, dynamic>.from(jsonDecode(data)) : {};
      setState(() {
        posts = List<Map<String, dynamic>>.from(decoded['posts'] ?? []);
        isLoading = false;
      });
    } else {
      setState(() { isLoading = false; });
    }
  }

  // 삭제 API 함수 추가
  Future<void> _deletePost(int postId) async {
    final uri = Uri.parse('http://127.0.0.1:5000/api/community/post/$postId');
    final response = await http.delete(uri, headers: {
      'Authorization': 'Bearer ${widget.token}',
    });
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('게시글이 삭제되었습니다.')));
      fetchPosts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: ${response.statusCode}')));
    }
  }

  // 게시글 수정 다이얼로그
  Future<void> _showEditDialog(Map<String, dynamic> post) async {
    final controller = TextEditingController(text: post['description'] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 수정'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(hintText: '내용을 입력하세요'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('수정'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await _editPost(post['id'], result.trim());
    }
  }

  // 게시글 수정 API
  Future<void> _editPost(int postId, String newContent) async {
    final uri = Uri.parse('http://127.0.0.1:5000/api/community/post/$postId');
    final response = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'description': newContent}),
    );
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('게시글이 수정되었습니다.')));
      fetchPosts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('수정 실패: ${response.statusCode}')));
    }
  }

  // 좋아요 토글
  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final uri = Uri.parse('http://127.0.0.1:5000/api/community/like');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'post_id': post['id']}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        post['liked'] = data['liked'];
        post['like_count'] = data['like_count'];
        // posts 리스트의 해당 post도 갱신
        final idx = posts.indexWhere((p) => p['id'] == post['id']);
        if (idx != -1) {
          posts[idx]['like_count'] = data['like_count'];
          posts[idx]['liked'] = data['liked'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '검색',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) {
            fetchPosts(query: value);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WritePostPage(token: widget.token)),
              );
              fetchPosts();
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              fetchPosts(query: _searchController.text);
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchPosts,
              child: ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, idx) {
                  final post = posts[idx];
                  final isMine = post['user_id'] == widget.userId;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상단: 프로필 + 닉네임
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundImage: AssetImage('assets/profile_placeholder.png'),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              post['username'] ?? 'user_${post['user_id'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (isMine)
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _showEditDialog(post);
                                  } else if (value == 'delete') {
                                    await _deletePost(post['id']);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('수정')),
                                  const PopupMenuItem(value: 'delete', child: Text('삭제')),
                                ],
                              ),
                          ],
                        ),
                      ),
                      // 이미지
                      if (post['image'] != null && post['image'] != '')
                        Image.network(
                          post['image'].toString().startsWith('http')
                              ? post['image']
                              : 'http://127.0.0.1:5000/${post['image']}', // 실제 배포 시 IP로 변경
                          width: double.infinity,
                          height: 320,
                          fit: BoxFit.cover,
                        ),
                      // 내용/해시태그
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (post['description'] != null && post['description'] != '')
                              Text.rich(highlightHashtags(post['description']), style: const TextStyle(fontSize: 16)),
                            // TODO: 해시태그 표시 (post['hashtag'] 등)
                          ],
                        ),
                      ),
                      // 좋아요/댓글 아이콘
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                post['liked'] == true ? Icons.favorite : Icons.favorite_border,
                                color: post['liked'] == true ? Colors.red : null,
                              ),
                              onPressed: () => _toggleLike(post),
                            ),
                            Text('${post['like_count'] ?? 0}'),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.comment),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostDetailPage(
                                      post: post,
                                      token: widget.token,
                                      userId: widget.userId,
                                      onCommentCountChanged: (newCount) {
                                        setState(() {
                                          final idx = posts.indexWhere((p) => p['id'] == post['id']);
                                          if (idx != -1) posts[idx]['comment_count'] = newCount;
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            Text('${post['comment_count'] ?? 0}'),
                          ],
                        ),
                      ),
                      const Divider(height: 24, thickness: 1),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

// 본문에서 #해시태그 하이라이트 표시 함수
TextSpan highlightHashtags(String text) {
  final regex = RegExp(r'(#[\w가-힣]+)');
  final matches = regex.allMatches(text);
  if (matches.isEmpty) return TextSpan(text: text);
  List<TextSpan> spans = [];
  int last = 0;
  for (final m in matches) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
    }
    spans.add(TextSpan(
      text: m.group(0),
      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
    ));
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last)));
  }
  return TextSpan(children: spans);
}

class WritePostPage extends StatefulWidget {
  final String token;
  const WritePostPage({Key? key, required this.token}) : super(key: key);
  @override
  State<WritePostPage> createState() => _WritePostPageState();
}

class _WritePostPageState extends State<WritePostPage> {
  final TextEditingController contentController = TextEditingController();
  File? _imageFile;

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _imageFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submitPost() async {
    final token = widget.token;
    final uri = Uri.parse('http://127.0.0.1:5000/api/community/post');
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['description'] = contentController.text;
    if (_imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));
    }
    try {
      final response = await request.send();
      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('글이 등록되었습니다.')));
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('글 등록 실패: \n${response.statusCode}')));
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
      appBar: AppBar(
        title: const Text('새 게시물'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _submitPost,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '내용을 입력해주세요 (예: 오늘 #OOTD #데일리룩)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _imageFile == null
                        ? const Icon(Icons.add)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final String token;
  final int userId;
  final void Function(int)? onCommentCountChanged;
  const PostDetailPage({required this.post, required this.token, required this.userId, this.onCommentCountChanged, Key? key}) : super(key: key);
  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  List<Map<String, dynamic>> comments = [];
  bool isLoading = false;
  final TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchComments();
  }

  Future<void> fetchComments() async {
    setState(() { isLoading = true; });
    final uri = Uri.parse('http://127.0.0.1:5000/api/community/comments/${widget.post['id']}');
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer ${widget.token}',
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
        isLoading = false;
      });
      // 댓글 개수 콜백 호출
      widget.onCommentCountChanged?.call(comments.length);
    } else {
      setState(() { isLoading = false; });
    }
  }

  Future<void> submitComment() async {
    final content = commentController.text.trim();
    if (content.isEmpty) return;
    final uri = Uri.parse('http://127.0.0.1:5000/api/community/comment');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'post_id': widget.post['id'], 'content': content}),
    );
    if (response.statusCode == 201) {
      commentController.clear();
      await fetchComments();
      // 댓글 개수 콜백 호출
      widget.onCommentCountChanged?.call(comments.length);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('댓글 등록 실패: ${response.statusCode}')));
    }
  }

  // 댓글 수정/삭제 API 함수 추가 (PostDetailPage의 State에)
  Future<void> _editComment(int commentId, String newContent) async {
    final uri = Uri.parse('http://127.0.0.1:5000/api/community/comment/$commentId');
    final response = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'content': newContent}),
    );
    if (response.statusCode == 200) {
      await fetchComments();
      widget.onCommentCountChanged?.call(comments.length);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('댓글 수정 실패: ${response.statusCode}')));
    }
  }
  Future<void> _deleteComment(int commentId) async {
    final uri = Uri.parse('http://127.0.0.1:5000/api/community/comment/$commentId');
    final response = await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
      },
    );
    if (response.statusCode == 200) {
      await fetchComments();
      widget.onCommentCountChanged?.call(comments.length);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('댓글 삭제 실패: ${response.statusCode}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, comments.length);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('게시글 상세')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.post['image'] != null)
              Image.network(
                widget.post['image'].toString().startsWith('http')
                    ? widget.post['image']
                    : 'http://127.0.0.1:5000/${widget.post['image']}',
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text.rich(highlightHashtags(widget.post['description'] ?? ''), style: const TextStyle(fontSize: 18)),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    widget.post['liked'] == true ? Icons.favorite : Icons.favorite_border,
                    color: widget.post['liked'] == true ? Colors.red : null,
                  ),
                  onPressed: () async {
                    await (context.findAncestorStateOfType<_CommunityPageState>()?._toggleLike(widget.post));
                    setState(() {});
                  },
                ),
                Text('${widget.post['like_count'] ?? 0}'),
                IconButton(
                  icon: const Icon(Icons.comment),
                  onPressed: () {},
                ),
                Text('${comments.length}'),
              ],
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('댓글', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, idx) {
                        final c = comments[idx];
                        return ListTile(
                          leading: const CircleAvatar(
                            radius: 18,
                            backgroundImage: AssetImage('assets/profile_placeholder.png'), // 실제 이미지 있으면 교체
                          ),
                          title: Text(
                            c['username'] ?? 'user_${c['user_id']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            c['content'] ?? '',
                            style: const TextStyle(fontSize: 15),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(c['created_at']?.substring(0, 10) ?? '', style: const TextStyle(fontSize: 12)),
                              if (c['user_id'] == widget.userId)
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      final controller = TextEditingController(text: c['content'] ?? '');
                                      final result = await showDialog<String>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('댓글 수정'),
                                          content: TextField(
                                            controller: controller,
                                            maxLines: 3,
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                                            TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('수정')),
                                          ],
                                        ),
                                      );
                                      if (result != null && result.trim().isNotEmpty) {
                                        await _editComment(c['id'], result.trim());
                                      }
                                    } else if (value == 'delete') {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('댓글 삭제'),
                                          content: const Text('정말 삭제하시겠습니까?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await _deleteComment(c['id']);
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: Text('수정')),
                                    const PopupMenuItem(value: 'delete', child: Text('삭제')),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      decoration: const InputDecoration(hintText: '댓글을 입력하세요'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: submitComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 