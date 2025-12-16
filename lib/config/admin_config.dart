const Set<String> adminUserIds = {'bOVmtHT4hIglo2UCtv297l3ZwfK2'};

bool isAdminUserId(String? userId) {
  if (userId == null || userId.isEmpty) {
    return false;
  }
  return adminUserIds.contains(userId);
}
