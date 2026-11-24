import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/product_model.dart';
import '../providers/cart_provider.dart';

class AssistantReply {
  final String text;
  final ProductModel? productAction;
  final bool openCart;

  AssistantReply({
    required this.text,
    this.productAction,
    this.openCart = false,
  });
}

class VoiceAssistantService {
  static final VoiceAssistantService _instance =
      VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isSpeechInitialized = false;
  bool _isTtsInitialized = false;

  Future<bool> initSpeech() async {
    if (_isSpeechInitialized) return true;
    try {
      _isSpeechInitialized = await _speech.initialize(
        onError: (err) => {},
        onStatus: (status) => {},
      );
      return _isSpeechInitialized;
    } catch (_) {
      return false;
    }
  }

  Future<void> initTts() async {
    if (_isTtsInitialized) return;
    try {
      await _tts.setLanguage('es-ES');
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5);
      _isTtsInitialized = true;
    } catch (_) {}
  }

  bool get isListening => _speech.isListening;

  Future<void> startListening({
    required Function(String recognized) onResult,
    required Function() onDone,
  }) async {
    final ready = await initSpeech();
    if (!ready) return;

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
      ),
      onResult: (val) {
        onResult(val.recognizedWords);
        if (val.finalResult) {
          onDone();
        }
      },
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> speak(String text) async {
    await initTts();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Procesa el mensaje del usuario (voz o texto) y retorna una respuesta inteligente
  AssistantReply processUserQuery(String query, CartProvider cart) {
    final q = query.toLowerCase().trim();

    // 1. Acciones relacionadas con la Tienda y Productos
    if (q.contains('carrito') || q.contains('ver compras')) {
      return AssistantReply(
        text:
            'Tienes ${cart.totalItemCount} productos en tu carrito sumando Bs. ${cart.totalAmount.toStringAsFixed(2)}. ¿Deseas revisarlo ahora?',
        openCart: true,
      );
    }

    // Agregar o consultar Gorra
    if (q.contains('gorra')) {
      final product = cart.products.firstWhere(
        (p) => p.nombre.toLowerCase().contains('gorra'),
        orElse: () => ProductModel(
          id: 'gorra-default',
          nombre: 'Gorra Oficial TurisApp',
          precio: 45.0,
          stock: 50,
          imagenUrl:
              'https://images.unsplash.com/photo-1588850561407-ed78c282e89b?auto=format&fit=crop&w=600&q=80',
        ),
      );

      if (q.contains('agrega') || q.contains('añadir') || q.contains('comprar') || q.contains('dame')) {
        cart.addItem(product);
        return AssistantReply(
          text:
              '¡Listo! He agregado la Gorra Oficial de TurisApp (Bs. 45) a tu carrito.',
          productAction: product,
        );
      } else {
        return AssistantReply(
          text:
              'La Gorra Oficial TurisApp tiene un precio de Bs. 45. Está hecha de tela fresca con visera curva y escudo bordado. ¿Deseas que la agregue a tu carrito?',
          productAction: product,
        );
      }
    }

    // Polera
    if (q.contains('polera') || q.contains('camiseta')) {
      final product = cart.products.firstWhere(
        (p) => p.nombre.toLowerCase().contains('polera'),
        orElse: () => ProductModel(
          id: 'polera-default',
          nombre: 'Polera Dry-Fit Senderismo',
          precio: 75.0,
          stock: 40,
          imagenUrl:
              'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=600&q=80',
        ),
      );

      if (q.contains('agrega') || q.contains('añadir') || q.contains('comprar') || q.contains('dame')) {
        cart.addItem(product);
        return AssistantReply(
          text:
              '¡Añadido! La Polera Dry-Fit (Bs. 75) ya está en tu carrito de compras.',
          productAction: product,
        );
      } else {
        return AssistantReply(
          text:
              'La Polera Dry-Fit cuesta Bs. 75. Es ideal para caminatas y días calurosos en Santa Cruz. ¿La agregamos al carrito?',
          productAction: product,
        );
      }
    }

    // Toma todo / Termo
    if (q.contains('toma todo') || q.contains('tomatodo') || q.contains('botella') || q.contains('termo')) {
      final product = cart.products.firstWhere(
        (p) => p.nombre.toLowerCase().contains('toma') || p.nombre.toLowerCase().contains('termo'),
        orElse: () => ProductModel(
          id: 'termo-default',
          nombre: 'Toma Todo / Termo Aventura 750ml',
          precio: 55.0,
          stock: 60,
          imagenUrl:
              'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=600&q=80',
        ),
      );

      if (q.contains('agrega') || q.contains('añadir') || q.contains('comprar') || q.contains('dame')) {
        cart.addItem(product);
        return AssistantReply(
          text:
              '¡Listo! El Toma Todo de Acero Inoxidable (Bs. 55) ha sido añadido a tu carrito.',
          productAction: product,
        );
      } else {
        return AssistantReply(
          text:
              'El Toma Todo de Aventura de 750ml cuesta Bs. 55. Mantiene el agua fría hasta por 24 horas. ¿Deseas comprarlo?',
          productAction: product,
        );
      }
    }

    // Mochila
    if (q.contains('mochila')) {
      final product = cart.products.firstWhere(
        (p) => p.nombre.toLowerCase().contains('mochila'),
        orElse: () => ProductModel(
          id: 'mochila-default',
          nombre: 'Mochila de Viaje Impermeable 30L',
          precio: 165.0,
          stock: 20,
          imagenUrl:
              'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
        ),
      );

      if (q.contains('agrega') || q.contains('añadir') || q.contains('comprar') || q.contains('dame')) {
        cart.addItem(product);
        return AssistantReply(
          text:
              '¡Excelente elección! La Mochila de Viaje Impermeable 30L (Bs. 165) ya está en tu carrito.',
          productAction: product,
        );
      } else {
        return AssistantReply(
          text:
              'La Mochila Impermeable 30L tiene un precio de Bs. 165. Incluye compartimentos especiales para senderismo y laptop. ¿La agregamos?',
          productAction: product,
        );
      }
    }

    // Sombrero Saó
    if (q.contains('sombrero') || q.contains('sao') || q.contains('saó')) {
      final product = cart.products.firstWhere(
        (p) => p.nombre.toLowerCase().contains('saó') || p.nombre.toLowerCase().contains('sao'),
        orElse: () => ProductModel(
          id: 'sao-default',
          nombre: 'Sombrero Saó Artesanal',
          precio: 35.0,
          stock: 30,
          imagenUrl:
              'https://images.unsplash.com/photo-1572495641004-28421ae52e52?auto=format&fit=crop&w=600&q=80',
        ),
      );

      if (q.contains('agrega') || q.contains('añadir') || q.contains('comprar')) {
        cart.addItem(product);
        return AssistantReply(
          text:
              '¡Auténtico recuerdo! He añadido el Sombrero Saó Artesanal (Bs. 35) a tu carrito.',
          productAction: product,
        );
      } else {
        return AssistantReply(
          text:
              'El Sombrero Saó Artesanal cuesta Bs. 35 y es tejido a mano por artesanos cruceños. ¿Deseas adquirirlo?',
          productAction: product,
        );
      }
    }

    // Catálogo general de tienda
    if (q.contains('producto') || q.contains('tienda') || q.contains('souvenir') || q.contains('vender') || q.contains('comprar')) {
      return AssistantReply(
        text:
            'En nuestra tienda oficial contamos con: Gorra Oficial (Bs. 45), Polera Dry-Fit (Bs. 75), Toma Todo 750ml (Bs. 55), Mochila Impermeable (Bs. 165) y Sombrero Saó (Bs. 35). Puedes decirme por ejemplo "agrega una gorra" para sumarla a tu carrito.',
      );
    }

    // Pagos
    if (q.contains('pago') || q.contains('qr') || q.contains('pagar')) {
      return AssistantReply(
        text:
            'Aceptamos pagos por QR Simple de cualquier banco de Bolivia. Cuando finalices tu pedido, te mostraremos el QR; luego subes el comprobante (en imagen o PDF) y nuestro sistema lo validará de inmediato.',
      );
    }

    // Respuestas turísticas contextualizadas
    if (q.contains('güembé') || q.contains('guembe')) {
      return AssistantReply(
        text:
            'El Biocentro Güembé es un paraíso ecológico en el Urubó con piscinas naturales, mariposario y aviario gigante. ¡Es una visita obligatoria en Santa Cruz!',
      );
    }

    if (q.contains('lomas') || q.contains('arena')) {
      return AssistantReply(
        text:
            'Las Lomas de Arena son un área protegida con dunas de arena blanca que alcanzan hasta 12 metros de altura, ideal para hacer sandboard y avistar fauna local.',
      );
    }

    if (q.contains('samaipata')) {
      return AssistantReply(
        text:
            'Samaipata se encuentra en los valles cruceños y alberga El Fuerte, una monumental roca tallada declarada Patrimonio de la Humanidad por la UNESCO.',
      );
    }

    if (q.contains('comer') || q.contains('comida') || q.contains('restaurante') || q.contains('plato')) {
      return AssistantReply(
        text:
            'En Santa Cruz debes probar el Majadito tostado, el Locro de gallina, el Cuñapé caliente, los Tamales y el Sonso de yuca. En la sección de Mapa e Inicio encontrarás excelentes restaurantes tradicionales.',
      );
    }

    if (q.contains('hola') || q.contains('buenos días') || q.contains('buenas tardes')) {
      return AssistantReply(
        text:
            '¡Hola! Soy tu asistente de TurisApp. Puedo ayudarte a buscar destinos turísticos, planear tu ruta en micro o agregar souvenirs y productos a tu carrito. ¿De qué te gustaría hablar?',
      );
    }

    // Respuesta inteligente genérica
    return AssistantReply(
      text:
          'Comprendo tu consulta sobre "$query". Te recomiendo explorar nuestra sección de Inicio y Mapa para ver los mejores destinos de Santa Cruz, o decirme "ver productos" para conocer los souvenirs disponibles en tu carrito.',
    );
  }
}
