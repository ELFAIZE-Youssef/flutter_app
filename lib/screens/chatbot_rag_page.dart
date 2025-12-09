import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ChatbotRagPage extends StatefulWidget {
  const ChatbotRagPage({super.key});

  @override
  State<ChatbotRagPage> createState() => _ChatbotRagPageState();
}

class _ChatbotRagPageState extends State<ChatbotRagPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  final String _apiUrl = 'http://10.0.2.2:8000'; // Pour émulateur Android
  
  bool _isLoading = false;
  bool _ragEnabled = false;
  List<String> _uploadedFiles = [];
  double _temperature = 0.7;
  int _topKChunks = 3;

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  // Créer une session
  Future<void> _createSession() async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/session/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': _sessionId}),
      );

      if (response.statusCode == 200) {
        print('Session créée: $_sessionId');
      }
    } catch (e) {
      print('Erreur création session: $e');
    }
  }

  // Upload documents
  Future<void> _uploadDocuments() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() => _isLoading = true);

        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$_apiUrl/documents/upload/$_sessionId'),
        );

        for (var file in result.files) {
          if (file.path != null) {
            request.files.add(
              await http.MultipartFile.fromPath('files', file.path!),
            );
          }
        }

        var response = await request.send();
        var responseData = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseData);
          setState(() {
            _uploadedFiles = List<String>.from(data['filenames']);
            _ragEnabled = true;
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ ${data['files_processed']} fichier(s) chargé(s) - ${data['chunks_created']} chunks créés',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          setState(() => _isLoading = false);
          throw Exception('Erreur upload');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Envoyer message
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    
    setState(() {
      _messages.add({
        'role': 'user',
        'content': userMessage,
      });
      _isLoading = true;
    });

    _messageController.clear();

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': userMessage,
          'session_id': _sessionId,
          'model': 'llama3:latest',
          'temperature': _temperature,
          'top_p': 0.9,
          'top_k': 40,
          'max_tokens': 512,
          'rag_enabled': _ragEnabled,
          'top_k_chunks': _topKChunks,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': data['response'],
            'sources': data['sources'],
          });
          _isLoading = false;
        });
      } else {
        throw Exception('Erreur: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Erreur de connexion à l\'API. Vérifiez que FastAPI est lancé.',
        });
        _isLoading = false;
      });
      print('Erreur: $e');
    }
  }

  // Clear chat
  Future<void> _clearChat() async {
    try {
      await http.delete(
        Uri.parse('$_apiUrl/session/$_sessionId/clear'),
      );
      setState(() => _messages.clear());
    } catch (e) {
      print('Erreur clear: $e');
    }
  }

  // Afficher les paramètres
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⚙️ Paramètres',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // RAG Toggle
              SwitchListTile(
                title: const Text('Activer RAG'),
                subtitle: Text(_uploadedFiles.isEmpty 
                    ? 'Uploadez des documents d\'abord' 
                    : '${_uploadedFiles.length} document(s) chargé(s)'),
                value: _ragEnabled,
                onChanged: _uploadedFiles.isEmpty ? null : (value) {
                  setState(() => _ragEnabled = value);
                  setModalState(() => _ragEnabled = value);
                },
              ),
              
              // Temperature
              ListTile(
                title: const Text('Temperature'),
                subtitle: Slider(
                  value: _temperature,
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  label: _temperature.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() => _temperature = value);
                    setModalState(() => _temperature = value);
                  },
                ),
                trailing: Text(_temperature.toStringAsFixed(1)),
              ),
              
              // Top K Chunks
              if (_ragEnabled)
                ListTile(
                  title: const Text('Nombre de chunks'),
                  subtitle: Slider(
                    value: _topKChunks.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: _topKChunks.toString(),
                    onChanged: (value) {
                      setState(() => _topKChunks = value.toInt());
                      setModalState(() => _topKChunks = value.toInt());
                    },
                  ),
                  trailing: Text(_topKChunks.toString()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMSI RAG Chatbot'),
        backgroundColor: Colors.teal,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _uploadDocuments,
            tooltip: 'Upload documents',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Paramètres',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Effacer le chat?'),
                  content: const Text('Voulez-vous vraiment effacer la conversation?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () {
                        _clearChat();
                        Navigator.pop(context);
                      },
                      child: const Text('Effacer'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Effacer le chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          if (_uploadedFiles.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.green.shade100,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '📚 ${_uploadedFiles.length} document(s): ${_uploadedFiles.join(", ")}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_ragEnabled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'RAG ON',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
          
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Commencez une conversation',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Uploadez des documents pour activer RAG',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['role'] == 'user';

                      return Column(
                        crossAxisAlignment: isUser 
                            ? CrossAxisAlignment.end 
                            : CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: isUser 
                                ? Alignment.centerRight 
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.teal : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                message['content']!,
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          
                          // Sources (si disponibles)
                          if (!isUser && message['sources'] != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 4),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text(
                                  '📚 Sources',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                children: [
                                  for (int i = 0; i < message['sources'].length; i++)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Source ${i + 1}: ${message['sources'][i]}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          
          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          
          // Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Écrivez votre message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
