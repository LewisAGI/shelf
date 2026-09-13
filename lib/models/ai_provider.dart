/// Bring-your-own AI provider. Shelf calls the user's endpoint with their key.
enum AiProvider {
  openai,
  openaiCompatible,
  anthropic,
}

extension AiProviderX on AiProvider {
  String get label => switch (this) {
    AiProvider.openai => 'OpenAI',
    AiProvider.openaiCompatible => 'OpenAI-compatible',
    AiProvider.anthropic => 'Anthropic',
  };

  String get presetBaseUrl => switch (this) {
    AiProvider.openai => 'https://api.openai.com/v1',
    AiProvider.openaiCompatible => '',
    AiProvider.anthropic => 'https://api.anthropic.com',
  };

  String get presetModel => switch (this) {
    AiProvider.openai => 'gpt-4o-mini',
    AiProvider.openaiCompatible => 'gpt-4o-mini',
    AiProvider.anthropic => 'claude-sonnet-4-5',
  };

  bool get allowsCustomBaseUrl => this == AiProvider.openaiCompatible;

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

class AiAskRequest {
  const AiAskRequest({
    required this.noteText,
    this.selectedText,
    this.documentTitle,
    this.page,
  });

  final String noteText;
  final String? selectedText;
  final String? documentTitle;
  final int? page;

  bool get hasAnythingToAsk {
    return noteText.trim().isNotEmpty || (selectedText?.trim().isNotEmpty ?? false);
  }
}

class AiVerifyResult {
  const AiVerifyResult({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}
