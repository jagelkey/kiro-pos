import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../data/models/branch.dart';
import '../../data/models/user.dart';
import '../../data/repositories/branch_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../../data/repositories/product_repository.dart'; // For RepositoryResult
import '../auth/auth_provider.dart';

final cloudBranchRepositoryProvider = Provider((ref) => CloudRepository());

/// Provider for branch list
final branchListProvider =
    StateNotifierProvider<BranchListNotifier, AsyncValue<List<Branch>>>((ref) {
  return BranchListNotifier(ref);
});

class BranchListNotifier extends StateNotifier<AsyncValue<List<Branch>>> {
  final Ref ref;
  final BranchRepository _repository = BranchRepository();

  BranchListNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadBranches();
  }

  Future<void> loadBranches() async {
    state = const AsyncValue.loading();
    try {
      final authState = ref.read(authProvider);
      final user = authState.user;

      if (user == null) {
        state = AsyncValue.error('User tidak ditemukan', StackTrace.current);
        return;
      }

      // Only owner can view branches
      if (user.role != UserRole.owner) {
        state = AsyncValue.error(
            'Hanya Owner yang dapat mengakses cabang', StackTrace.current);
        return;
      }

      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final cloudRepo = ref.read(cloudBranchRepositoryProvider);
          final branches = await cloudRepo.getBranchesByOwner(user.id);
          state = AsyncValue.data(branches);
          return;
        } catch (e) {
          debugPrint('Cloud branches load failed, falling back to local: $e');
        }
      }

      final branches = await _repository.getBranchesByOwner(user.id);
      state = AsyncValue.data(branches);
    } catch (e, st) {
      state = AsyncValue.error('Gagal memuat data cabang: $e', st);
    }
  }

  /// Retry loading after error
  void retry() => loadBranches();

  BranchRepository get repository => _repository;
}

/// Provider for managing branch operations
class BranchProvider extends ChangeNotifier {
  final BranchRepository _repository = BranchRepository();
  final CloudRepository _cloudRepository = CloudRepository();

  List<Branch> _branches = [];
  Branch? _selectedBranch;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Branch> get branches => _branches;
  Branch? get selectedBranch => _selectedBranch;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all branches for an owner
  Future<void> loadBranches(String ownerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          _branches = await _cloudRepository.getBranchesByOwner(ownerId);
          _isLoading = false;
          notifyListeners();
          return;
        } catch (e) {
          debugPrint('Cloud branches load failed, falling back to local: $e');
        }
      }

      _branches = await _repository.getBranchesByOwner(ownerId);
    } catch (e) {
      _error = 'Failed to load branches: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select a branch
  void selectBranch(Branch? branch) {
    _selectedBranch = branch;
    notifyListeners();
  }

  /// Create a new branch
  Future<RepositoryResult<Branch>> createBranch(Branch branch) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final created = await _cloudRepository.createBranch(branch);
          _branches.add(created);
          _branches.sort((a, b) => a.name.compareTo(b.name));
          return RepositoryResult.success(created);
        } catch (e) {
          debugPrint('Cloud branch create failed, falling back to local: $e');
        }
      }

      final result = await _repository.createBranch(branch);
      if (result.success) {
        _branches.add(result.data!);
        _branches.sort((a, b) => a.name.compareTo(b.name));
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing branch
  Future<RepositoryResult<Branch>> updateBranch(Branch branch) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          await _cloudRepository.updateBranch(branch);
          final index = _branches.indexWhere((b) => b.id == branch.id);
          if (index != -1) {
            _branches[index] = branch;
          }
          return RepositoryResult.success(branch);
        } catch (e) {
          debugPrint('Cloud branch update failed, falling back to local: $e');
        }
      }

      final result = await _repository.updateBranch(branch);
      if (result.success) {
        final index = _branches.indexWhere((b) => b.id == branch.id);
        if (index != -1) {
          _branches[index] = result.data!;
        }
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle branch active status
  Future<RepositoryResult<Branch>> toggleStatus(
      String id, bool isActive) async {
    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final branch = await _cloudRepository.getBranchById(id);
          if (branch != null) {
            final updated = Branch(
              id: branch.id,
              ownerId: branch.ownerId,
              name: branch.name,
              code: branch.code,
              address: branch.address,
              phone: branch.phone,
              taxRate: branch.taxRate,
              isActive: isActive,
              createdAt: branch.createdAt,
              updatedAt: DateTime.now(),
            );
            await _cloudRepository.updateBranch(updated);
            final index = _branches.indexWhere((b) => b.id == id);
            if (index != -1) {
              _branches[index] = updated;
            }
            return RepositoryResult.success(updated);
          }
        } catch (e) {
          debugPrint('Cloud branch toggle failed, falling back to local: $e');
        }
      }

      final result = isActive
          ? await _repository.activateBranch(id)
          : await _repository.deactivateBranch(id);
      if (result.success) {
        final index = _branches.indexWhere((b) => b.id == id);
        if (index != -1) {
          _branches[index] = result.data!;
        }
      }
      return result;
    } finally {
      notifyListeners();
    }
  }

  /// Delete a branch
  Future<RepositoryResult<bool>> deleteBranch(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          await _cloudRepository.deleteBranch(id);
          _branches.removeWhere((b) => b.id == id);
          if (_selectedBranch?.id == id) {
            _selectedBranch = null;
          }
          return RepositoryResult.success(true);
        } catch (e) {
          debugPrint('Cloud branch delete failed, falling back to local: $e');
        }
      }

      final result = await _repository.deleteBranch(id);
      if (result.success) {
        _branches.removeWhere((b) => b.id == id);
        if (_selectedBranch?.id == id) {
          _selectedBranch = null;
        }
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all state
  void clear() {
    _branches = [];
    _selectedBranch = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
