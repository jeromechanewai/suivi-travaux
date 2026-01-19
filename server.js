const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;

const server = http.createServer((req, res) => {
    let filePath = req.url === '/' ? '/preview.html' : req.url;
    filePath = path.join(__dirname, filePath);

    const ext = path.extname(filePath);
    const contentTypes = {
        '.html': 'text/html',
        '.css': 'text/css',
        '.js': 'application/javascript',
        '.json': 'application/json',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.svg': 'image/svg+xml'
    };

    fs.readFile(filePath, (err, content) => {
        if (err) {
            res.writeHead(404);
            res.end('File not found');
        } else {
            res.writeHead(200, { 'Content-Type': contentTypes[ext] || 'text/plain' });
            res.end(content);
        }
    });
});

server.listen(PORT, () => {
    console.log(`
╔════════════════════════════════════════════════════════╗
║                                                        ║
║   🏗️  CHANTIER LIGHT - Serveur de développement       ║
║                                                        ║
║   Ouvre dans ton navigateur:                          ║
║   👉  http://localhost:${PORT}                           ║
║                                                        ║
║   Pour tester sur mobile (même WiFi):                 ║
║   👉  http://[ton-ip-locale]:${PORT}                     ║
║                                                        ║
║   Ctrl+C pour arrêter le serveur                      ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
`);
});
