## 假装成编辑器的调试器：收 `--remote-debug` 发来的脚本警告，一行一条 JSON 写到文件。
## 引擎只在连着调试器时才报 GDScript 静态警告（整数除法、重名、未用变量……），无头跑测试看不到；
## 用 [code]tools/warnings.sh[/code] 一次把全项目的脚本加载一遍、把警告收齐。
extends SceneTree

var _server := TCPServer.new()
var _peer: PacketPeerStream = null
var _out: FileAccess = null
var _idle := 0.0
var _got := 0


func _initialize() -> void:
	_out = FileAccess.open(OS.get_environment("WARN_OUT"), FileAccess.WRITE)
	var err := _server.listen(int(OS.get_environment("WARN_PORT")), "127.0.0.1")
	if err != OK or _out == null:
		push_error("warnings_collector: listen=%d out=%s" % [err, OS.get_environment("WARN_OUT")])
		quit(1)


func _process(delta: float) -> bool:
	if _peer == null:
		_idle += delta
		if _idle > 120.0:
			print("warnings_collector: no client, giving up")
			return true
		if _server.is_connection_available():
			_peer = PacketPeerStream.new()
			_peer.stream_peer = _server.take_connection()
		return false
	var tcp := _peer.stream_peer as StreamPeerTCP
	tcp.poll()
	while _peer.get_available_packet_count() > 0:
		var v: Variant = _peer.get_var()
		if not (v is Array) or (v as Array).is_empty():
			continue
		var msg := String(v[0])
		if msg == "error":
			_out.store_line(JSON.stringify(v[-1]))
			_got += 1
		elif msg == "debug_enter":
			_peer.put_var(["continue", 1, []])
	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_out.close()
		print("warnings_collector: %d" % _got)
		return true
	return false
