fn main() {
    println!("cargo:rustc-check-cfg=cfg(threadless_wasm)");
    if std::env::var("TARGET").as_deref() == Ok("wasm32-wasip1") {
        println!("cargo:rustc-cfg=threadless_wasm");
    }
}
