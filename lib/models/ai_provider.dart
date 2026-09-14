/// Bring-your-own AI provider. Shelf calls the user's endpoint with their key.
enum AiProvider {
  openai,
  anthropic,
  grok,
  openaiCompatible,
}

extension AiProviderX on AiProvider {
  String get label => switch (this) {
    AiProvider.openai => 'OpenAI',
    AiProvider.anthropic => 'Anthropic',
    AiProvider.grok => 'Grok (xAI)',
    AiProvider.openaiCompatible => 'OpenAI-compatible',
  };

  String get presetBaseUrl => switch (this) {
    AiProvider.openai => 'https://api.openai.com/v1',
    AiProvider.anthropic => 'https://api.anthropic.com',
    AiProvider.grok => 'https://api.x.ai/v1',
    AiProvider.openaiCompatible => '',
  };

  String get presetModel => switch (this) {
    AiProvider.openai => 'gpt-4o-mini',
    AiProvider.anthropic => 'claude-sonnet-4-5',
    AiProvider.grok => 'grok-4.6',
    AiProvider.openaiCompatible => 'gpt-4o-mini',
  };

  /// Known chat models for the Settings dropdown. "Custom" is always extra.
  List<String> get knownModels => switch (this) {
    AiProvider.openai => const [
      'gpt-4o-mini',
      'gpt-4o',
      'gpt-4.1-mini',
      'gpt-4.1',
      'o4-mini',
    ],
    AiProvider.anthropic => const [
      'claude-sonnet-4-5',
      'claude-opus-4-5',
      'claude-haiku-4-5',
      'claude-sonnet-4-0',
    ],
    AiProvider.grok => const [
      'grok-4.6',
      'grok-4',
      'grok-3-mini',
      'grok-3',
    ],
    AiProvider.openaiCompatible => const [
      'gpt-4o-mini',
      'llama-3.1-8b',
    ],
  };

  bool get allowsCustomBaseUrl => this == AiProvider.openaiCompatible;

  /// Anthropic Messages accepts PDF document blocks. OpenAI chat completions
  /// accept a `file` content part. xAI documents image input, not PDF parts.
  /// Custom compatible servers are not assumed to take PDF file parts.
  bool get supportsPdfAttachment => switch (this) {
    AiProvider.anthropic => true,
    AiProvider.openai => true,
    AiProvider.grok => false,
    AiProvider.openaiCompatible => false,
  };

  String get pdfUnsupportedReason => switch (this) {
    AiProvider.grok =>
      'xAI chat completions document image input, not PDF file parts.',
    AiProvider.openaiCompatible =>
      'Custom OpenAI-compatible endpoints are not assumed to accept PDF file parts.',
    AiProvider.openai =>
      'OpenAI chat completions rejected or cannot take this PDF on the path Shelf uses.',
    AiProvider.anthropic =>
      'Anthropic Messages could not take this PDF on the path Shelf uses.',
  };

  bool get usesOpenAiCompatibleApi => this != AiProvider.anthropic;

  String get id => name;

  static AiProvider fromId(String? id) {
    return AiProvider.values.cast<AiProvider?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => AiProvider.openai,
        ) ??
        AiProvider.openai;
  }
}

/// In-memory connection used for verify / ask. The key is never logged.
class AiConnection {
  const AiConnection({
    required this.provider,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  final AiProvider provider;
  final String baseUrl;
  final String model;
  final String apiKey;

  bool get hasKey => apiKey.trim().isNotEmpty;

  String get resolvedBaseUrl {
    final typed = baseUrl.trim();
    if (typed.isNotEmpty) {
      return _stripTrailingSlash(typed);
    }
    return _stripTrailingSlash(provider.presetBaseUrl);
  }

  String get resolvedModel {
    final typed = model.trim();
    return typed.isEmpty ? provider.presetModel : typed;
  }

  static String _stripTrailingSlash(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}

class AiNoteSnippet {
  const AiNoteSnippet({
    required this.text,
    required this.page,
    this.selectedText,
    this.labelName,
  });

  final String text;
  final int page;
  final String? selectedText;
  final String? labelName;
}

class AiAskRequest {
  const AiAskRequest({
    required this.noteText,
    this.selectedText,
    this.documentTitle,
    this.page,
    this.notes = const [],
    this.pdfBytes,
    this.pdfFileName,
    this.pdfSkippedReason,
  });

  final String noteText;
  final String? selectedText;
  final String? documentTitle;
  final int? page;
  final List<AiNoteSnippet> notes;
  final List<int>? pdfBytes;
  final String? pdfFileName;
  final String? pdfSkippedReason;

  bool get hasPdf => pdfBytes != null && pdfBytes!.isNotEmpty;

  bool get isBookAsk => notes.length > 1;

  bool get hasAnythingToAsk {
    if (noteText.trim().isNotEmpty) {
      return true;
    }
    if (selectedText?.trim().isNotEmpty ?? false) {
      return true;
    }
    return notes.any(
      (note) =>
          note.text.trim().isNotEmpty ||
          (note.selectedText?.trim().isNotEmpty ?? false),
    );
  }
}

class AiAskOutcome {
  const AiAskOutcome({required this.reply, this.pdfNotice});

  final String reply;
  final String? pdfNotice;
}

class AiVerifyResult {
  const AiVerifyResult({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}
