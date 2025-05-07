//! build_tpch.rs
//! -----------------------------------------------------------
//! Automate TPC-H dbgen build and .tbl generation for SF=1 & 10 on a MySQL workload
//! -----------------------------------------------------------

use anyhow::{bail, Context, Result};
use glob::glob;
use std::{
    fs,
    path::Path,
    process::{Command, Stdio},
};

// ---------------------------------------------------------------------------
// Paths & scales
// ---------------------------------------------------------------------------

const MAKEFILE_PATH: &str = "./tpc-h-utils/makefile";
const DBGEN_SRC_FOLDER: &str = "./tpc-h-tool/dbgen";
const DBGEN_BIN: &str = "./tpc-h-tool/dbgen/dbgen";
const TBL_S1_OUTPUT_FOLDER: &str  = "./tpc-h-s1-dataset";
const TBL_S10_OUTPUT_FOLDER: &str = "./tpc-h-s10-dataset";

const SCALE_FACTORS: &[(u32, &str)] = &[
    (1,  TBL_S1_OUTPUT_FOLDER),
    (10, TBL_S10_OUTPUT_FOLDER),
];

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

fn main() -> Result<()> {
    verify_layout()?;
    build_dbgen_if_needed()?;

    for &(sf, out_dir) in SCALE_FACTORS {
        generate_tbl(sf, out_dir)?;
    }

    println!("✔ All done – datasets are ready.");
    Ok(())
}

// ---------------------------------------------------------------------------
// 1) Check that ./tpc-h-tool/dbgen exists
// ---------------------------------------------------------------------------

fn verify_layout() -> Result<()> {
    if !Path::new(DBGEN_SRC_FOLDER).exists() {
        bail!(
            "'{}' is missing – please clone the TPC-H source tree there",
            DBGEN_SRC_FOLDER
        );
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// 2) Build the dbgen binary, patching makefile if needed
// ---------------------------------------------------------------------------

fn build_dbgen_if_needed() -> Result<()> {
    let src = Path::new(DBGEN_SRC_FOLDER);
    let bin = Path::new(DBGEN_BIN);
    let mf = src.join("makefile");

    // Ensure makefile exists and is configured
    if !mf.exists() {
        println!("🔧  makefile not found in dbgen dir, copying from {}", MAKEFILE_PATH);
        fs::copy(MAKEFILE_PATH, &mf)
            .with_context(|| format!(
                "failed to copy makefile from '{}' to '{}'",
                MAKEFILE_PATH,
                mf.display()
            ))?;
    }

    if bin.exists() {
        println!("📦  dbgen already built – skipping");
        return Ok(());
    }

    println!("🔨  Building dbgen …");
    run(
        Command::new("make")
            .current_dir(&src)
    )?;

    if !bin.exists() {
        bail!("dbgen binary was not produced; please inspect the make output");
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// 3) Run dbgen in the source dir and move the *.tbl files into place
// ---------------------------------------------------------------------------

fn generate_tbl(scale: u32, out_dir: &str) -> Result<()> {
    println!("🗃  Generating scale {} → {}", scale, out_dir);

    fs::create_dir_all(out_dir)
        .with_context(|| format!("cannot create output directory '{}'", out_dir))?;

    let src = Path::new(DBGEN_SRC_FOLDER);

    // Ensure distributions file is present
    let dist = src.join("dists.dss");
    if !dist.exists() {
        bail!("missing distributions file '{}'", dist.display());
    }

    // Run dbgen directly in the source folder
    run(
        Command::new("./dbgen")
            .current_dir(&src)
            .arg("-vf")      // verbose + force overwrite
            .arg("-s")
            .arg(scale.to_string()),
    )
    .with_context(|| format!("dbgen failed for scale {}", scale))?;

    // Move all .tbl files out
    let pattern = src.join("*.tbl").to_str().unwrap().to_string();
    for entry in glob(&pattern)? {
        let p = entry?;
        let file_name = p.file_name().unwrap();
        fs::rename(&p, Path::new(out_dir).join(file_name))?;
    }

    println!("   → done scale {}", scale);
    Ok(())
}

// ---------------------------------------------------------------------------
// Helper to run a command and bail on non-zero exit
// ---------------------------------------------------------------------------

fn run(cmd: &mut Command) -> Result<()> {
    let status = cmd
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .with_context(|| format!("failed to run {:?}", cmd))?;
    if !status.success() {
        bail!("{:?} exited with {}", cmd, status);
    }
    Ok(())
}
