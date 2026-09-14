import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_provider.dart';

/// Calls the user's provider. Shelf never holds a house API key.
abstract class AiClient {
  Future<AiVerifyResult> verify(AiConnection connection);

  Future<AiAskOutcome> askAbout(AiConnection connection, AiAskRequest request);
}

class HttpAiClient implements AiClient {
  HttpAiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const anthropicVersion = '2023-06-01';
  static const askMaxTokens = 500;
  static const bookAskMaxTokens = 2000;
  static const maxPdfBytes = 20 * 1024 * 1024;
  static const timeout = Duration(seconds: 45);

  @override
  Future<AiVerifyResult> verify(AiConnection connection) async {
    if (!connection.hasKey) {
      return const AiVerifyResult(
        ok: false,
        message: 'Add an API key first.',
      );
    }
    if (connection.resolvedBaseUrl.isEmpty) {
      return const AiVerifyResult(
        ok: false,
        message: 'Add a base URL for this provider.',
      );
    }
    try {
      if (connection.provider == AiProvider.anthropic) {
        return await _verifyAnthropic(connection);
      }
      return await _verifyOpenAiCompatible(connection);
    } on AiClientException catch (error) {
      return AiVerifyResult(ok: false, message: error.message);
    } on Object catch (error) {
      return AiVerifyResult(ok: false, message: _friendlyNetworkError(error));
    }
  }

  @override
  Future<AiAskOutcome> askAbout(
    AiConnection connection,
    AiAskRequest request,
  ) async {
    if (!connection.hasKey) {
      throw const AiClientException(
        'Add your own API key in Settings — Shelf does not provide one.',
      );
    }
    if (!request.hasAnythingToAsk) {
      throw const AiClientException('Write a note or select text first.');
    }
    if (connection.resolvedBaseUrl.isEmpty) {
      throw const AiClientException('Add a base URL for this provider.');
    }
    final prepared = preparePdf(connection, request);
    try {
      final reply = connection.provider == AiProvider.anthropic
          ? await _askAnthropic(connection, prepared)
          : await _askOpenAiCompatible(connection, prepared);
      return AiAskOutcome(reply: reply, pdfNotice: prepared.pdfSkippedReason);
    } on AiClientException {
      rethrow;
    } on Object catch (error) {
      throw AiClientException(_friendlyNetworkError(error));
    }
  }

  /// Drop or keep PDF bytes according to provider support and size.
  static AiAskRequest preparePdf(AiConnection connection, AiAskRequest request) {
    if (!request.hasPdf) {
      return request;
    }
    if (!connection.provider.supportsPdfAttachment) {
      return _withoutPdf(
        request,
        request.pdfSkippedReason ?? connection.provider.pdfUnsupportedReason,
      );
    }
    final bytes = request.pdfBytes!;
    if (bytes.length > maxPdfBytes) {
      final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      return _withoutPdf(
        request,
        'PDF is $mb MB — too large to attach (limit 20 MB). Notes sent without the file.',
      );
    }
    return request;
  }

  static AiAskRequest _withoutPdf(AiAskRequest request, String reason) {
    return AiAskRequest(
      noteText: request.noteText,
      selectedText: request.selectedText,
      documentTitle: request.documentTitle,
      page: request.page,
      notes: request.notes,
      pdfSkippedReason: reason,
    );
  }

  Future<AiVerifyResult> _verifyOpenAiCompatible(
    AiConnection connection,
  ) async {
    final modelsUri = _join(connection.resolvedBaseUrl, '/models');
    final modelsResponse = await _http
        .get(modelsUri, headers: _openAiHeaders(connection.apiKey))
        .timeout(timeout);
    if (modelsResponse.statusCode >= 200 && modelsResponse.statusCode < 300) {
      final count = _openaiModelCount(modelsResponse.body);
      return AiVerifyResult(
        ok: true,
        message: count == null
            ? 'Connected. Models list looks good.'
            : 'Connected. Provider listed $count models.',
      );
    }
    if (modelsResponse.statusCode == 404) {
      return _verifyOpenAiWithTinyChat(connection);
    }
    throw AiClientException(
      _httpErrorMessage(modelsResponse.statusCode, modelsResponse.body),
    );
  }

  Future<AiVerifyResult> _verifyOpenAiWithTinyChat(
    AiConnection connection,
  ) async {
    final response = await _http
        .post(
          _join(connection.resolvedBaseUrl, '/chat/completions'),
          headers: _openAiHeaders(connection.apiKey),
          body: jsonEncode({
            'model': connection.resolvedModel,
            'messages': [
              {'role': 'user', 'content': 'ping'},
            ],
            'max_tokens': 1,
          }),
        )
        .timeout(timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return const AiVerifyResult(
        ok: true,
        message: 'Connected. Chat completions accepted the key.',
      );
    }
    throw AiClientException(
      _httpErrorMessage(response.statusCode, response.body),
    );
  }

  Future<AiVerifyResult> _verifyAnthropic(AiConnection connection) async {
    final response = await _http
        .get(
          _join(connection.resolvedBaseUrl, '/v1/models'),
          headers: _anthropicHeaders(connection.apiKey),
        )
        .timeout(timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final count = _anthropicModelCount(response.body);
      return AiVerifyResult(
        ok: true,
        message: count == null
            ? 'Connected. Anthropic models list looks good.'
            : 'Connected. Anthropic listed $count models.',
      );
    }
    throw AiClientException(
      _httpErrorMessage(response.statusCode, response.body),
    );
  }

  Future<String> _askOpenAiCompatible(
    AiConnection connection,
    AiAskRequest request,
  ) async {
    final response = await _http
        .post(
          _join(connection.resolvedBaseUrl, '/chat/completions'),
          headers: _openAiHeaders(connection.apiKey),
          body: jsonEncode({
            'model': connection.resolvedModel,
            'messages': [
              {
                'role': 'user',
                'content': _openAiUserContent(request),
              },
            ],
            'max_tokens': request.isBookAsk ? bookAskMaxTokens : askMaxTokens,
          }),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiClientException(
        _httpErrorMessage(response.statusCode, response.body),
      );
    }
    final text = _openaiReply(response.body);
    if (text == null || text.trim().isEmpty) {
      throw const AiClientException('The provider returned an empty reply.');
    }
    return text.trim();
  }

  Future<String> _askAnthropic(
    AiConnection connection,
    AiAskRequest request,
  ) async {
    final response = await _http
        .post(
          _join(connection.resolvedBaseUrl, '/v1/messages'),
          headers: _anthropicHeaders(connection.apiKey),
          body: jsonEncode({
            'model': connection.resolvedModel,
            'max_tokens': request.isBookAsk ? bookAskMaxTokens : askMaxTokens,
            'messages': [
              {
                'role': 'user',
                'content': _anthropicUserContent(request),
              },
            ],
          }),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiClientException(
        _httpErrorMessage(response.statusCode, response.body),
      );
    }
    final text = _anthropicReply(response.body);
    if (text == null || text.trim().isEmpty) {
      throw const AiClientException('The provider returned an empty reply.');
    }
    return text.trim();
  }

  static Object _openAiUserContent(AiAskRequest request) {
    final prompt = buildAskPrompt(request);
    if (!request.hasPdf) {
      return prompt;
    }
    final name = request.pdfFileName?.trim().isNotEmpty == true
        ? request.pdfFileName!.trim()
        : 'document.pdf';
    final b64 = base64Encode(request.pdfBytes!);
    return [
      {'type': 'text', 'text': prompt},
      {
        'type': 'file',
        'file': {
          'filename': name,
          'file_data': 'data:application/pdf;base64,$b64',
        },
      },
    ];
  }

  static Object _anthropicUserContent(AiAskRequest request) {
    final prompt = buildAskPrompt(request);
    if (!request.hasPdf) {
      return prompt;
    }
    return [
      {
        'type': 'document',
        'source': {
          'type': 'base64',
          'media_type': 'application/pdf',
          'data': base64Encode(request.pdfBytes!),
        },
      },
      {'type': 'text', 'text': prompt},
    ];
  }

  static String buildAskPrompt(AiAskRequest request) {
    final buffer = StringBuffer(
      'You are helping with a personal PDF reading note. '
      'Be concise and useful. Do not mention being an AI unless asked.\n',
    );
    final skipped = request.pdfSkippedReason?.trim();
    if (skipped != null && skipped.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('The PDF could not be attached: $skipped')
        ..writeln('Answer from the notes and quoted text only.');
    } else if (request.hasPdf) {
      buffer.writeln(
        'A PDF of the book is attached. Use it when the notes refer to the page.',
      );
    }
    final title = request.documentTitle?.trim();
    if (title != null && title.isNotEmpty) {
      buffer.writeln('Document: $title');
    }
    if (request.page != null) {
      buffer.writeln('Page: ${request.page}');
    }
    if (request.notes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln("The reader's notes, in page order:");
      for (final note in request.notes) {
        buffer.write('- Page ${note.page}');
        final label = note.labelName?.trim();
        if (label != null && label.isNotEmpty) {
          buffer.write(' · $label');
        }
        buffer.writeln(':');
        final quoted = note.selectedText?.trim();
        if (quoted != null && quoted.isNotEmpty) {
          buffer.writeln('  Quoted: $quoted');
        }
        final text = note.text.trim();
        if (text.isNotEmpty) {
          buffer.writeln('  Note: $text');
        }
      }
    } else {
      final quoted = request.selectedText?.trim();
      if (quoted != null && quoted.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('Quoted text from the page:')
          ..writeln(quoted);
      }
      final note = request.noteText.trim();
      if (note.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln("The reader's note:")
          ..writeln(note);
      }
    }
    buffer
      ..writeln()
      ..writeln(
        request.notes.length > 1
            ? 'Summarise the notes and help the reader see the thread.'
            : (request.selectedText?.trim().isNotEmpty ?? false)
            ? 'Explain or expand on the note in the context of the quoted passage.'
            : 'Explain or expand on this note.',
      );
    return buffer.toString();
  }

  Map<String, String> _openAiHeaders(String apiKey) {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }

  Map<String, String> _anthropicHeaders(String apiKey) {
    return {
      'x-api-key': apiKey,
      'anthropic-version': anthropicVersion,
      'Content-Type': 'application/json',
    };
  }

  static Uri _join(String base, String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized');
  }

  static int? _openaiModelCount(String body) {
    final decoded = _tryJson(body);
    final data = decoded?['data'];
    if (data is List) {
      return data.length;
    }
    return null;
  }

  static int? _anthropicModelCount(String body) {
    final decoded = _tryJson(body);
    final data = decoded?['data'];
    if (data is List) {
      return data.length;
    }
    return null;
  }

  static String? _openaiReply(String body) {
    final decoded = _tryJson(body);
    final choices = decoded?['choices'];
    if (choices is! List || choices.isEmpty) {
      return null;
    }
    final first = choices.first;
    if (first is! Map) {
      return null;
    }
    final message = first['message'];
    if (message is Map && message['content'] is String) {
      return message['content'] as String;
    }
    if (first['text'] is String) {
      return first['text'] as String;
    }
    return null;
  }

  static String? _anthropicReply(String body) {
    final decoded = _tryJson(body);
    final content = decoded?['content'];
    if (content is! List || content.isEmpty) {
      return null;
    }
    final buffer = StringBuffer();
    for (final block in content) {
      if (block is Map && block['text'] is String) {
        buffer.write(block['text']);
      }
    }
    return buffer.toString();
  }

  static Map<String, Object?>? _tryJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
    } on Object {
      // Non-JSON error bodies are handled by the caller.
    }
    return null;
  }

  static String _httpErrorMessage(int status, String body) {
    final decoded = _tryJson(body);
    final error = decoded?['error'];
    if (error is Map && error['message'] is String) {
      return 'HTTP $status: ${error['message']}';
    }
    if (error is String && error.trim().isNotEmpty) {
      return 'HTTP $status: $error';
    }
    if (decoded?['message'] is String) {
      return 'HTTP $status: ${decoded!['message']}';
    }
    return 'HTTP $status from the provider.';
  }

  static String _friendlyNetworkError(Object _) {
    return 'Could not reach the provider. Check the URL and network.';
  }
}

class AiClientException implements Exception {
  const AiClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
