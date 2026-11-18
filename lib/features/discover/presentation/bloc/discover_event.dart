import 'package:equatable/equatable.dart';

import '../../data/repositories/discover_repository.dart';

sealed class DiscoverEvent extends Equatable {
  const DiscoverEvent();

  @override
  List<Object?> get props => [];
}

/// Primary feed-replacing events handled with `restartable()` concurrency.
sealed class DiscoverFeedLoadEvent extends DiscoverEvent {
  const DiscoverFeedLoadEvent();
}

final class DiscoverInitialLoaded extends DiscoverFeedLoadEvent {
  const DiscoverInitialLoaded();
}

final class DiscoverCategorySelected extends DiscoverFeedLoadEvent {
  const DiscoverCategorySelected(this.category);

  final DiscoverCategory category;

  @override
  List<Object?> get props => [category];
}

final class DiscoverGenreSelected extends DiscoverFeedLoadEvent {
  const DiscoverGenreSelected(this.genreId);

  final int? genreId;

  @override
  List<Object?> get props => [genreId];
}

final class DiscoverSearchChanged extends DiscoverFeedLoadEvent {
  const DiscoverSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class DiscoverSearchCleared extends DiscoverFeedLoadEvent {
  const DiscoverSearchCleared();
}

final class DiscoverRetried extends DiscoverFeedLoadEvent {
  const DiscoverRetried();
}

/// Pagination event handled with `droppable()` to ignore duplicate triggers.
final class DiscoverNextPageLoaded extends DiscoverEvent {
  const DiscoverNextPageLoaded();
}

