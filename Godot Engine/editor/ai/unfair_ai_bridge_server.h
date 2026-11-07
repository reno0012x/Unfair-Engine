#pragma once

#include "core/crypto/crypto.h"
#include "core/io/tcp_server.h"
#include "core/object/ref_counted.h"
#include "core/variant/array.h"
#include "core/variant/dictionary.h"

// An opt-in, main-thread-only, read-only local bridge. This is not an HTTP server.
class UnfairAIBridgeServer : public RefCounted {
	GDCLASS(UnfairAIBridgeServer, RefCounted);

	struct Connection {
		Ref<StreamPeerTCP> peer;
		Vector<uint8_t> incoming;
		Vector<uint8_t> outgoing;
		int sent = 0;
		Dictionary session;
		uint64_t accepted_msec = 0;
		uint64_t last_seen_msec = 0;
		bool authenticated = false;
	};

	Ref<TCPServer> listener;
	Ref<Crypto> crypto;
	Vector<Connection> connections;
	Array sessions;
	Array activity;
	String token;
	int port = 0;
	uint64_t next_session = 0;
	uint64_t next_call = 0;
	uint64_t call_count = 0;
	uint64_t error_count = 0;
	uint64_t bytes_returned = 0;

	void _disconnect(Connection &p_connection, const String &p_status);
	bool _queue(Connection &p_connection, const Dictionary &p_response);
	Dictionary _request(Connection &p_connection, const String &p_line);
	Dictionary _tool(const String &p_name, const Dictionary &p_arguments, bool &r_error);
	bool _safe_path(const String &p_path, String &r_absolute, String &r_error) const;
	static bool _allowed_resource_path(const String &p_path);
	Dictionary _protocol_error(const Variant &p_id, int p_code, const String &p_message);
	static Dictionary _tool_error(const String &p_message);

protected:
	static void _bind_methods();

public:
	Error start();
	void stop();
	void poll();
	bool is_running() const;
	int get_port() const;
	String get_token() const;
	Array get_sessions() const;
	Array get_activity() const;
	Array get_catalog() const;
	Dictionary get_stats() const;
	~UnfairAIBridgeServer();
};
