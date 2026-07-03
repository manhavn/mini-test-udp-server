use std::net::UdpSocket;
use std::str;

struct Args {
    port: u16,
    bind_addr: String,
    response: Option<String>,
    show_help: bool,
}

fn parse_args() -> Result<Args, String> {
    let mut args = std::env::args().skip(1);
    let mut port = 9999;
    let mut bind_addr = "0.0.0.0".to_string();
    let mut response = None;
    let mut show_help = false;

    while let Some(arg) = args.next() {
        match arg.as_str() {
            "-p" | "--port" => {
                if let Some(p_str) = args.next() {
                    port = p_str.parse::<u16>().map_err(|_| format!("Cổng không hợp lệ: '{}'", p_str))?;
                } else {
                    return Err("Thiếu giá trị cho tham số cổng (-p/--port)".to_string());
                }
            }
            "-b" | "--bind" => {
                if let Some(b_str) = args.next() {
                    bind_addr = b_str;
                } else {
                    return Err("Thiếu giá trị cho tham số địa chỉ bind (-b/--bind)".to_string());
                }
            }
            "-r" | "--response" => {
                if let Some(r_str) = args.next() {
                    response = Some(r_str);
                } else {
                    return Err("Thiếu giá trị cho tham số phản hồi (-r/--response)".to_string());
                }
            }
            "-h" | "--help" => {
                show_help = true;
            }
            _ => {
                return Err(format!("Tham số không xác định: '{}'. Sử dụng -h hoặc --help để xem hướng dẫn.", arg));
            }
        }
    }

    Ok(Args {
        port,
        bind_addr,
        response,
        show_help,
    })
}

fn print_help() {
    println!(r#"{bold}{green}=== MINI TEST UDP SERVER CLI ==={reset}
{bold}Mô tả:{reset}
  Khởi chạy một UDP server kiểm thử đơn giản, lắng nghe trên cổng tùy chọn
  và tự động phản hồi dữ liệu nhận được cho client.

{bold}Cách chạy:{reset}
  mini-test-udp-server [OPTIONS]

{bold}Các tham số (OPTIONS):{reset}
  {cyan}-p, --port <PORT>{reset}      Cổng để lắng nghe (Mặc định: {yellow}9999{reset})
  {cyan}-b, --bind <ADDRESS>{reset}   Địa chỉ IP để bind (Mặc định: {yellow}0.0.0.0{reset})
  {cyan}-r, --response <TEXT>{reset}  Nội dung phản hồi tĩnh gửi lại client.
                            Nếu không truyền tham số này, server sẽ hoạt động ở
                            chế độ {bold}ECHO{reset} (gửi lại chính xác những gì nhận được).
  {cyan}-h, --help{reset}             Hiển thị hướng dẫn sử dụng này.

{bold}CÁC LỆNH MẪU ĐỂ GỬI UDP PACKET & KIỂM TRA (TESTING DEMOS):{reset}

{bold}1. Sử dụng Netcat (nc):{reset}
   * Gửi tin nhắn một dòng và nhận phản hồi trực tiếp:
     {yellow}echo "Hello UDP Server" | nc -u -w 1 127.0.0.1 9999{reset}
   * Chế độ tương tác (Gửi liên tục và xem phản hồi, gõ Ctrl+C để thoát):
     {yellow}nc -u 127.0.0.1 9999{reset}

{bold}2. Sử dụng Bash /dev/udp (Chỉ gửi, không nhận phản hồi ngược lại):{reset}
   * Gửi một tin nhắn nhanh đến server:
     {yellow}echo "Message via /dev/udp/" > /dev/udp/127.0.0.1/9999{reset}
   * Gửi nội dung của một file:
     {yellow}cat my_file.txt > /dev/udp/127.0.0.1/9999{reset}

{bold}3. Sử dụng Python (Kiểm tra gửi và nhận phản hồi đầy đủ):{reset}
   {yellow}python3 -c 'import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.sendto(b"Hello from Python", ("127.0.0.1", 9999)); print("Phản hồi:", s.recvfrom(1024)[0].decode())'{reset}

{bold}4. Sử dụng Socat:{reset}
   * Gửi và nhận phản hồi:
     {yellow}echo "Hello via socat" | socat - UDP:127.0.0.1:9999{reset}

{bold}5. Sử dụng Nmap (Kiểm tra trạng thái cổng UDP):{reset}
   * Quét kiểm tra trạng thái cổng UDP 9999 (Cần quyền root/sudo):
     {yellow}sudo nmap -sU -p 9999 127.0.0.1{reset}
"#,
    bold = "\x1b[1m",
    green = "\x1b[32m",
    yellow = "\x1b[33m",
    cyan = "\x1b[36m",
    reset = "\x1b[0m"
    );
}

fn start_server(args: Args) -> std::io::Result<()> {
    let bind_target = format!("{}:{}", args.bind_addr, args.port);
    println!("\x1b[1m\x1b[32m[SERVER] Đang khởi chạy UDP Server...\x1b[0m");
    
    let socket = UdpSocket::bind(&bind_target)?;
    println!("\x1b[1m\x1b[36m[SERVER] Lắng nghe tại: {}\x1b[0m", bind_target);
    
    if let Some(ref resp) = args.response {
        println!("\x1b[33m[SERVER] Chế độ phản hồi: Phản hồi tĩnh (Static response)\x1b[0m");
        println!("         Nội dung phản hồi: \"{}\"", resp);
    } else {
        println!("\x1b[33m[SERVER] Chế độ phản hồi: ECHO (Phản hồi lại dữ liệu nhận được)\x1b[0m");
    }
    println!("[SERVER] Sẵn sàng nhận gói tin. Nhấn Ctrl+C để dừng server.\n");

    let mut buf = [0u8; 65535]; // Max UDP packet size is 65535 bytes

    loop {
        match socket.recv_from(&mut buf) {
            Ok((amt, src)) => {
                let received_data = &buf[..amt];
                // Try to parse received bytes to UTF-8 string for easy logging
                let msg_str = match str::from_utf8(received_data) {
                    Ok(v) => format!("\"{}\"", v.trim_end()),
                    Err(_) => format!("(Dữ liệu nhị phân / Non-UTF8, độ dài {} bytes)", amt),
                };

                println!(
                    "\x1b[32m[+] Nhận {} bytes từ {}:\x1b[0m {}",
                    amt, src, msg_str
                );

                // Determine what response to send
                let response_bytes = if let Some(ref resp) = args.response {
                    resp.as_bytes()
                } else {
                    received_data
                };

                // Send response back to sender
                match socket.send_to(response_bytes, src) {
                    Ok(sent_bytes) => {
                        let resp_str = match str::from_utf8(response_bytes) {
                            Ok(v) => format!("\"{}\"", v.trim_end()),
                            Err(_) => format!("(Dữ liệu nhị phân, {} bytes)", sent_bytes),
                        };
                        println!(
                            "    \x1b[36m[->] Đã phản hồi {} bytes cho {}:\x1b[0m {}",
                            sent_bytes, src, resp_str
                        );
                    }
                    Err(e) => {
                        eprintln!("    \x1b[31m[!] Lỗi khi phản hồi cho {}: {}\x1b[0m", src, e);
                    }
                }
            }
            Err(e) => {
                eprintln!("\x1b[31m[!] Lỗi khi nhận gói tin: {}\x1b[0m", e);
            }
        }
    }
}

fn main() {
    match parse_args() {
        Ok(args) => {
            if args.show_help {
                print_help();
                return;
            }

            if let Err(e) = start_server(args) {
                eprintln!("\x1b[31m[!] Lỗi khởi động server: {}\x1b[0m", e);
                std::process::exit(1);
            }
        }
        Err(e) => {
            eprintln!("\x1b[31m[!] Lỗi tham số: {}\x1b[0m", e);
            println!("Sử dụng -h hoặc --help để xem hướng dẫn sử dụng.");
            std::process::exit(1);
        }
    }
}
