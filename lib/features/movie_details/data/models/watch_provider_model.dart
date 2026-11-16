import 'package:equatable/equatable.dart';

enum WatchProviderType {
  stream('Stream'),
  rent('Rent'),
  buy('Buy');

  const WatchProviderType(this.label);

  final String label;
}

/// Streaming, rent, or buy provider returned from TMDB `/movie/{id}/watch/providers`.
class WatchProviderModel extends Equatable {
  const WatchProviderModel({
    required this.providerId,
    required this.providerName,
    this.logoPath,
    required this.type,
  });

  factory WatchProviderModel.fromJson(
    Map<String, dynamic> json, {
    required WatchProviderType type,
  }) {
    return WatchProviderModel(
      providerId: (json['provider_id'] as num?)?.toInt() ?? 0,
      providerName: (json['provider_name'] as String?) ?? 'Provider',
      logoPath: json['logo_path'] as String?,
      type: type,
    );
  }

  final int providerId;
  final String providerName;
  final String? logoPath;
  final WatchProviderType type;

  @override
  List<Object?> get props => [providerId, providerName, logoPath, type];
}
