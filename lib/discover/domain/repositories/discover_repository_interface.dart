import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';

abstract interface class DiscoverRepositoryInterface {
  Future<Result<DiscoverDashboardData>> getDashboardData();
}
