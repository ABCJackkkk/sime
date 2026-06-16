const http = require("http");
const fs = require("fs");
const path = require("path");
const root = "d:\\AR\\love_sim\\build\\web";
const mime = { ".html":"text/html", ".js":"text/javascript", ".css":"text/css", ".json":"application/json", ".png":"image/png", ".jpg":"image/jpeg", ".svg":"image/svg+xml", ".ttf":"font/ttf", ".otf":"font/otf", ".wasm":"application/wasm" };
http.createServer((req, res) => {
  let p = path.join(root, req.url === "/" ? "index.html" : req.url);
  fs.readFile(p, (err, data) => { if(err) { res.writeHead(404); res.end("404"); } else { res.writeHead(200, {"Content-Type": mime[path.extname(p)] || "text/plain"}); res.end(data); } });
}).listen(8080, () => console.log("Server at http://localhost:8080"));
