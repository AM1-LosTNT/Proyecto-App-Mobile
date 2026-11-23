import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import '../../services/voice_assistant_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_feedback.dart';
import '../shop/cart_screen.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  final _service = VoiceAssistantService();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<_ChatMessage> _messages = [
    _ChatMessage.assistant(
      '¡Hola! Soy Bimo, tu asistente de TurisApp. Puedo recomendarte lugares, '
      'contarte qué hacer en Santa Cruz o ayudarte con los souvenirs de la '
      'tienda. ¿Qué te gustaría saber?',
    ),
  ];

  bool _listening = false;
  bool _busy = false;
  String _liveText = '';
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _service.stopListening();
    _service.stopSpeaking();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? forced]) async {
    final text = (forced ?? _input.text).trim();
    if (text.isEmpty || _busy) return;

    final cart = context.read<CartProvider>();
    _input.clear();

    setState(() {
      _busy = true;
      _error = null;
      _messages.add(_ChatMessage.user(text));
    });
    _scrollToEnd();

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final reply = _service.processUserQuery(text, cart);

    setState(() {
      _busy = false;
      _messages.add(
        _ChatMessage.assistant(reply.text, canOpenCart: reply.openCart),
      );
    });
    _scrollToEnd();
    unawaited(_service.speak(reply.text));

    if (reply.openCart) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _service.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }

    setState(() {
      _error = null;
      _liveText = '';
    });

    final ready = await _service.initSpeech();
    if (!ready) {
      if (!mounted) return;
      setState(
        () => _error =
            'El micrófono no está disponible en este dispositivo. Puedes '
            'escribir tu mensaje.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _listening = true);

    await _service.startListening(
      onResult: (recognized) {
        if (!mounted) return;
        setState(() => _liveText = recognized);
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _listening = false);
        final text = _liveText.trim();
        _liveText = '';
        if (text.isNotEmpty) _send(text);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Asistente Bimo'),
        actions: [
          IconButton(
            tooltip: 'Silenciar voz',
            onPressed: _service.stopSpeaking,
            icon: const Icon(Icons.volume_off_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: InlineAlert(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _MessageBubble(
                message: _messages[index],
              ),
            ),
          ),
          if (_listening)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic_rounded, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _liveText.isEmpty ? 'Escuchando...' : _liveText,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: _listening ? 'Detener' : 'Hablar',
                    onPressed: _busy ? null : _toggleMic,
                    icon: Icon(
                      _listening ? Icons.stop_rounded : Icons.mic_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu mensaje...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    onPressed: _busy ? null : () => _send(),
                    icon: const Icon(Icons.send_rounded),
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

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool canOpenCart;

  const _ChatMessage._(this.text, this.isUser, this.canOpenCart);

  factory _ChatMessage.user(String text) => _ChatMessage._(text, true, false);

  factory _ChatMessage.assistant(String text, {bool canOpenCart = false}) =>
      _ChatMessage._(text, false, canOpenCart);
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isUser ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            if (message.canOpenCart) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Ver carrito'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
