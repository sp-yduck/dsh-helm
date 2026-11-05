// Byte-for-byte TCP relay from one concrete address to dsh on loopback.
// dsh rejects wildcard binds and kubectl port-forward dials the pod's loopback,
// so dsh listens on 127.0.0.1 and this relay serves the pod/container IP.
// It does not parse HTTP: dsh still enforces its launch token, session cookie,
// and Host/Origin checks on every request.
import net from "node:net";

const [listenHost, listenPort, targetPort] = process.argv.slice(2);
if (!listenHost || !listenPort || !targetPort) {
	console.error("usage: dsh-relay.mjs <listen-host> <listen-port> <target-port>");
	process.exit(2);
}

const server = net.createServer((client) => {
	const upstream = net.connect({ host: "127.0.0.1", port: Number(targetPort) });
	client.pipe(upstream).pipe(client);
	const close = () => {
		client.destroy();
		upstream.destroy();
	};
	client.on("error", close);
	upstream.on("error", close);
});

server.on("error", (error) => {
	console.error(`dsh-relay: ${error.message}`);
	process.exit(1);
});
server.listen({ host: listenHost, port: Number(listenPort) }, () => {
	console.error(`dsh-relay: ${listenHost}:${listenPort} -> 127.0.0.1:${targetPort}`);
});
