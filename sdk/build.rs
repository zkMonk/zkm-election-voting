fn main() -> Result<(), Box<dyn std::error::Error>> {
    if let Some(_snark_flag) = std::env::var_os("NO_USE_SNARK") {
        tonic_build::configure()
            .protoc_arg("--experimental_allow_proto3_optional")
            .compile(&["src/proto/stage.proto"], &["src/proto"])?;
    } else {
        let target_os = std::env::var("CARGO_CFG_TARGET_OS")?;
        if target_os == "macos" {
            println!("cargo:rustc-link-lib=dylib=snark");
        } else if target_os == "linux" {
            println!("cargo:rustc-link-lib=snark");
        }
        println!("cargo:rustc-link-search=native=./sdk/src/local/libsnark");
        tonic_build::configure()
            .protoc_arg("--experimental_allow_proto3_optional")
            .compile(&["src/proto/stage.proto"], &["src/proto"])?;
    }

    Ok(())
}