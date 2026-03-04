import frida
import sys
import time

print("=== 🕵️ FRIDA WIN/WINE SNIFFER (WSASend & EncryptMessage) ===")
print("Bizonyosodj meg róla, hogy a frida-server.exe fut a WINE prefixben!\n")

# A cél processz neve a WINE környezetben (MT5)
TARGET_PROCESS = "terminal64.exe"

# --- FRIDA JAVASCRIPT PAYLOAD ---
js_payload = """
// 1. WSASend Hook (ws2_32.dll) - Hálózati kapu
var ws2_32 = Module.load('ws2_32.dll');
var wsaSendPtr = ws2_32.getExportByName('WSASend');

if (wsaSendPtr) {
    Interceptor.attach(wsaSendPtr, {
        onEnter: function (args) {
            this.socket = args[0];
            this.lpBuffers = args[1]; // WSABUF*
            this.dwBufferCount = args[2].toInt32();

            // WSABUF struktúra: [ ulong len, char* buf ]
            var wsaBufLen = this.lpBuffers.readU32();
            var wsaBufPtr = this.lpBuffers.add(Process.pointerSize).readPointer();

            this.len = wsaBufLen;
            this.buf = wsaBufPtr;
        },
        onLeave: function (retval) {
            if (this.len > 0) {
                var payload = this.buf.readByteArray(this.len);
                send({
                    type: 'WSASend',
                    socket: this.socket.toInt32(),
                    len: this.len
                }, payload);
            }
        }
    });
    console.log("[+] WSASend Hook beállítva!");
}

// 2. EncryptMessage Hook (Secur32.dll / sspicli.dll) - A Kriptográfiai Aranybánya
// Az EncryptMessage függvény paraméterei (PCtxtHandle phContext, ULONG fQOP, PSecBufferDesc pMessage, ULONG MessageSeqNo)
var secur32 = Process.findModuleByName('Secur32.dll') || Process.findModuleByName('sspicli.dll');
if (secur32) {
    var encryptMsgPtr = secur32.findExportByName('EncryptMessage');
    if (encryptMsgPtr) {
        Interceptor.attach(encryptMsgPtr, {
            onEnter: function (args) {
                this.pMessage = args[2]; // PSecBufferDesc

                // SecBufferDesc: [ ULONG ulVersion, ULONG cBuffers, PSecBuffer pBuffers ]
                var cBuffers = this.pMessage.add(4).readU32();
                var pBuffers = this.pMessage.add(8).readPointer(); // x64-en a mutató a 8. bytetól kezdődik

                // Végigiterálunk a buffereken. Általában a SECBUFFER_DATA (1) típusú buffer tartalmazza a plaintextet.
                // SecBuffer: [ ULONG cbBuffer, ULONG BufferType, PVOID pvBuffer ] -> (x64) 4 byte méret, 4 byte típus, 8 byte mutató = 16 byte / struktúra
                for (var i = 0; i < cBuffers; i++) {
                    var bufferOffset = pBuffers.add(i * 16);
                    var cbBuffer = bufferOffset.readU32();
                    var bufferType = bufferOffset.add(4).readU32();
                    var pvBuffer = bufferOffset.add(8).readPointer();

                    if (bufferType === 1 && cbBuffer > 0) { // SECBUFFER_DATA
                        var plaintext = pvBuffer.readByteArray(cbBuffer);
                        send({
                            type: 'EncryptMessage (Plaintext)',
                            len: cbBuffer
                        }, plaintext);
                    }
                }
            }
        });
        console.log("[+] EncryptMessage Hook beállítva (Plaintext gyűjtése)!");
    } else {
        console.log("[-] EncryptMessage export nem található!");
    }
} else {
    console.log("[-] Secur32.dll nem található!");
}

// 3. send Hook (ws2_32.dll) - Biztonsági tartalék
var sendPtr = ws2_32.getExportByName('send');
if (sendPtr) {
    Interceptor.attach(sendPtr, {
        onEnter: function (args) {
            this.socket = args[0];
            this.buf = args[1];
            this.len = args[2].toInt32();
        },
        onLeave: function (retval) {
            if (this.len > 0) {
                var payload = this.buf.readByteArray(this.len);
                send({
                    type: 'send',
                    socket: this.socket.toInt32(),
                    len: this.len
                }, payload);
            }
        }
    });
    console.log("[+] send Hook beállítva!");
}
"""

def hexdump(src, length=16):
    FILTER = ''.join([(len(repr(chr(x))) == 3) and chr(x) or '.' for x in range(256)])
    lines = []
    for c in range(0, len(src), length):
        chars = src[c:c+length]
        hex_str = ' '.join([f"{x:02x}" for x in chars])
        printable = ''.join([FILTER[x] for x in chars])
        lines.append(f"{c:04x}  {hex_str:<{length*3}}  |{printable}|")
    return '\n'.join(lines)

def on_message(message, data):
    if message['type'] == 'send':
        payload = message['payload']
        print(f"\\n[+] ELKAPVA: {payload['type']} | Hossz: {payload['len']} bytes")
        if data:
            print(hexdump(data))
            print("-" * 50)
    else:
        print(message)

def main():
    try:
        # A Frida a lokális frida-server.exe-hez csatlakozik, ami a WINE-ban fut.
        # Ennek működéséhez Linuxon el kell indítani WINE alatt a win32/win64 frida servert.
        print(f"[*] Csatlakozás a(z) {TARGET_PROCESS} folyamathoz...")

        # Mivel a Linuxon futtatjuk, a device manageren keresztül próbáljuk elérni a WINE servert.
        # Általában a lokális USB eszközökön vagy a hálózaton fut (127.0.0.1).
        # Ha a frida-server.exe simán fut a WINE-ban, porton hallgat (default 27042).
        device = frida.get_device_manager().add_remote_device("127.0.0.1:27042")
        session = device.attach(TARGET_PROCESS)

        print("[+] Sikeres csatlakozás! Hookok injektálása...")
        script = session.create_script(js_payload)
        script.on('message', on_message)
        script.load()
        print("[*] Interception aktív. Várom az adatokat. (Ctrl+C kilépés)")
        sys.stdin.read()
    except frida.ServerNotRunningError:
        print("\\n[-] HIBA: A Frida server nem fut a célpontnál (127.0.0.1:27042).")
        print("    Indítsd el a WINE környezetben a frida-server.exe-t!")
        print("    Példa: WINEPREFIX=~/.wine wine frida-server.exe -l 127.0.0.1")
    except frida.ProcessNotFoundError:
        print(f"\\n[-] HIBA: A folyamat ({TARGET_PROCESS}) nem található!")
    except Exception as e:
        print(f"\\n[-] Váratlan hiba: {e}")

if __name__ == '__main__':
    main()
