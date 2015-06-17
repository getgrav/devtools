var args = process.argv.slice(2);

process.stdin.resume();
process.stdin.setEncoding('utf8');
process.stdin.on('data', function(data) {
    if (data.length <= 2 || !data.match(/{.+}/)) {
        process.stdout.write('');

        return;
    }

    var response = JSON.parse(data),
        assets = response.assets;

    if (!assets) { process.stdout.write(''); }
    else {
        for (var k in assets) {
            process.stdout.write(assets[k].id + ':' + assets[k].name + '\n');
        }
    }
});
