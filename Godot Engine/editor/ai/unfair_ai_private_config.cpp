#include "unfair_ai_private_config.h"

#include "core/templates/vector.h"

#ifdef WINDOWS_ENABLED
#include <windows.h>

#include <sddl.h>
#elif defined(UNIX_ENABLED)
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cerrno>
#endif

Error unfair_ai_write_private_config(const String &p_path, const String &p_text) {
	if (!p_path.is_absolute_path() || p_path.is_empty()) {
		return ERR_INVALID_PARAMETER;
	}
	for (int i = 0; i < p_path.length(); i++) {
		if (p_path[i] == 0) {
			return ERR_INVALID_PARAMETER;
		}
	}
	const CharString utf8 = p_text.utf8();
#ifdef WINDOWS_ENABLED
	HANDLE process_token = nullptr;
	if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &process_token)) {
		return ERR_UNAUTHORIZED;
	}
	DWORD token_size = 0;
	GetTokenInformation(process_token, TokenUser, nullptr, 0, &token_size);
	if (token_size == 0 || token_size > 65536) {
		CloseHandle(process_token);
		return ERR_UNAUTHORIZED;
	}
	Vector<uint8_t> token_info;
	token_info.resize(token_size);
	const BOOL token_ok = GetTokenInformation(process_token, TokenUser, token_info.ptrw(), token_size, &token_size);
	CloseHandle(process_token);
	if (!token_ok) {
		return ERR_UNAUTHORIZED;
	}
	const TOKEN_USER *user = reinterpret_cast<const TOKEN_USER *>(token_info.ptr());
	LPWSTR user_sid = nullptr;
	if (!ConvertSidToStringSidW(user->User.Sid, &user_sid)) {
		return ERR_UNAUTHORIZED;
	}
	// D:P protects the DACL from inheritance. Only the process user and SYSTEM
	// receive file access, even when the project lives in a shared directory.
	const String sddl = "D:P(A;;FA;;;SY)(A;;FA;;;" + String::utf16(reinterpret_cast<const char16_t *>(user_sid)) + ")";
	LocalFree(user_sid);
	PSECURITY_DESCRIPTOR descriptor = nullptr;
	if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(reinterpret_cast<LPCWSTR>(sddl.utf16().get_data()), SDDL_REVISION_1, &descriptor, nullptr)) {
		return ERR_UNAUTHORIZED;
	}
	SECURITY_ATTRIBUTES attributes = {};
	attributes.nLength = sizeof(attributes);
	attributes.lpSecurityDescriptor = descriptor;
	attributes.bInheritHandle = FALSE;
	// CREATE_NEW rejects both existing regular files and final-component links.
	// No sharing prevents another process renaming this file while we write it.
	// Godot undefines the Windows DELETE macro to protect enum names.
	constexpr DWORD delete_access = 0x00010000;
	HANDLE file = CreateFileW(reinterpret_cast<LPCWSTR>(p_path.utf16().get_data()), GENERIC_WRITE | delete_access, 0, &attributes, CREATE_NEW, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
	const DWORD create_error = file == INVALID_HANDLE_VALUE ? GetLastError() : ERROR_SUCCESS;
	LocalFree(descriptor);
	if (file == INVALID_HANDLE_VALUE) {
		return create_error == ERROR_FILE_EXISTS || create_error == ERROR_ALREADY_EXISTS ? ERR_ALREADY_EXISTS : ERR_CANT_CREATE;
	}
	bool success = true;
	int offset = 0;
	while (offset < utf8.length()) {
		DWORD written = 0;
		const DWORD amount = DWORD(MIN(utf8.length() - offset, 65536));
		if (!WriteFile(file, utf8.get_data() + offset, amount, &written, nullptr) || written == 0) {
			success = false;
			break;
		}
		offset += int(written);
	}
	if (success) {
		success = FlushFileBuffers(file);
	}
	if (!success) {
		// Mark the exact handle we created for deletion; never delete by a path
		// that could have been replaced by an unrelated file.
		FILE_DISPOSITION_INFO disposition = {};
		disposition.DeleteFile = TRUE;
		SetFileInformationByHandle(file, FileDispositionInfo, &disposition, sizeof(disposition));
	}
	const BOOL closed = CloseHandle(file);
	return success && closed ? OK : ERR_FILE_CANT_WRITE;
#elif defined(UNIX_ENABLED) && defined(O_NOFOLLOW)
	const CharString path = p_path.utf8();
	int flags = O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW;
#ifdef O_CLOEXEC
	flags |= O_CLOEXEC;
#endif
	const int file = ::open(path.get_data(), flags, S_IRUSR | S_IWUSR);
	if (file < 0) {
		return errno == EEXIST ? ERR_ALREADY_EXISTS : ERR_CANT_CREATE;
	}
	bool success = true;
	int offset = 0;
	while (offset < utf8.length()) {
		const ssize_t written = ::write(file, utf8.get_data() + offset, utf8.length() - offset);
		if (written < 0 && errno == EINTR) {
			continue;
		}
		if (written <= 0) {
			success = false;
			break;
		}
		offset += int(written);
	}
	if (success) {
		int flushed;
		do {
			flushed = ::fsync(file);
		} while (flushed < 0 && errno == EINTR);
		success = flushed == 0;
	}
	if (!success) {
		struct stat created = {};
		struct stat current = {};
		// Never remove an existing destination or a replacement with a different
		// identity. Keep the created descriptor open during cleanup.
		if (::fstat(file, &created) == 0 && ::lstat(path.get_data(), &current) == 0 && created.st_dev == current.st_dev && created.st_ino == current.st_ino) {
			::unlink(path.get_data());
		}
	}
	const int closed = ::close(file);
	return success && closed == 0 ? OK : ERR_FILE_CANT_WRITE;
#else
	// Fail closed instead of creating a credential file with unknown privacy.
	return ERR_UNAVAILABLE;
#endif
}
