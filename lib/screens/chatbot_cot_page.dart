import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotCotPage extends StatefulWidget {
  const ChatbotCotPage({super.key});

  @override
  State<ChatbotCotPage> createState() => _ChatbotCotPageState();
}

class _ChatbotCotPageState extends State<ChatbotCotPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  
  // Parameters
  bool _cotEnabled = true;
  double _temperature = 0.7;
  double _topP = 0.9;
  int _topK = 40;
  int _maxTokens = 1024;
  String _selectedModel = 'llama3';

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    
    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _isLoading = true;
    });

    _messageController.clear();

    try {
      // Préparer le prompt avec CoT
      String finalPrompt = userMessage;
      if (_cotEnabled) {
        finalPrompt = '''$userMessage

Réponds en utilisant ce format exact:

## Raisonnement
[Explique ton processus de réflexion étape par étape]

## Réponse
[Ta réponse finale et claire]''';
      }

      final response = await http.post(
        Uri.parse('http://10.0.2.2:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _selectedModel,
          'prompt': finalPrompt,
          'stream': false,
          'options': {
            'temperature': _temperature,
            'top_p': _topP,
            'top_k': _topK,
            'num_predict': _maxTokens,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final fullResponse = data['response'];
        
        // Parser CoT si activé
        if (_cotEnabled && fullResponse.contains('## Raisonnement') && fullResponse.contains('## Réponse')) {
          final parts = fullResponse.split('## Réponse');
          final reasoning = parts[0].replaceAll('## Raisonnement', '').trim();
          final answer = parts[1].trim();
          
          setState(() {
            _messages.add({
              'role': 'assistant',
              'content': answer,
              'reasoning': reasoning,
            });
            _isLoading = false;
          });
        } else {
          setState(() {
            _messages.add({
              'role': 'assistant',
              'content': fullResponse,
            });
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Erreur: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Erreur de connexion à Ollama. Assurez-vous qu\'Ollama est lancé.',
        });
        _isLoading = false;
      });
      print('Erreur: $e');
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const Text(
                '⚙️ Paramètres',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Model Selection
              DropdownButtonFormField<String>(
                value: _selectedModel,
                decoration: const InputDecoration(
                  labelText: 'Modèle',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'llama3', child: Text('Llama3')),
                  DropdownMenuItem(value: 'mistral', child: Text('Mistral')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedModel = value);
                    setModalState(() => _selectedModel = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // CoT Toggle
              SwitchListTile(
                title: const Text('Chain of Thoughts'),
                subtitle: const Text('Raisonnement étape par étape'),
                value: _cotEnabled,
                onChanged: (value) {
                  setState(() => _cotEnabled = value);
                  setModalState(() => _cotEnabled = value);
                },
              ),
              const Divider(),
              
              // Temperature
              ListTile(
                title: const Text('Temperature'),
                subtitle: Column(
                  children: [
                    Slider(
                      value: _temperature,
                      min: 0.0,
                      max: 2.0,
                      divisions: 40,
                      label: _temperature.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() => _temperature = value);
                        setModalState(() => _temperature = value);
                      },
                    ),
                    Text(_temperature.toStringAsFixed(2)),
                  ],
                ),
              ),
              
              // Top-P
              ListTile(
                title: const Text('Top-P'),
                subtitle: Column(
                  children: [
                    Slider(
                      value: _topP,
                      min: 0.0,
                      max: 1.0,
                      divisions: 100,
                      label: _topP.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() => _topP = value);
                        setModalState(() => _topP = value);
                      },
                    ),
                    Text(_topP.toStringAsFixed(2)),
                  ],
                ),
              ),
              
              // Top-K
              ListTile(
                title: const Text('Top-K'),
                subtitle: Column(
                  children: [
                    Slider(
                      value: _topK.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: _topK.toString(),
                      onChanged: (value) {
                        setState(() => _topK = value.toInt());
                        setModalState(() => _topK = value.toInt());
                      },
                    ),
                    Text(_topK.toString()),
                  ],
                ),
              ),
              
              // Max Tokens
              ListTile(
                title: const Text('Max Tokens'),
                subtitle: Column(
                  children: [
                    Slider(
                      value: _maxTokens.toDouble(),
                      min: 50,
                      max: 4096,
                      divisions: 80,
                      label: _maxTokens.toString(),
                      onChanged: (value) {
                        setState(() => _maxTokens = value.toInt());
                        setModalState(() => _maxTokens = value.toInt());
                      },
                    ),
                    Text(_maxTokens.toString()),
                  ],
                ),
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
        title: const Text('EMSI CoT Chatbot'),
        backgroundColor: Colors.teal,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() => _messages.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          if (_cotEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.blue.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.psychology, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Chain of Thoughts activé',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                          Icons.psychology_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chatbot avec raisonnement',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
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
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.teal
                                    : Colors.grey.shade200,
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
                          
                          // Reasoning expander
                          if (!isUser && message.containsKey('reasoning'))
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: const Text(
                                    '🧠 Voir le raisonnement',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        message['reasoning'],
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          
          // Loading
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