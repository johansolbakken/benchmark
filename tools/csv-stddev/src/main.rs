use anyhow::{Context, Result}; // Import Result and Context from anyhow
use clap::Parser;
use std::fs;

/// Calculate the standard deviation of a slice of f64 values
fn stddev(data: &[f64]) -> f64 {
    if data.len() < 2 {
        return f64::NAN;
    }
    let mean = data.iter().copied().sum::<f64>() / data.len() as f64;
    let variance = data.iter().map(|x| (*x - mean).powi(2)).sum::<f64>() / (data.len() - 1) as f64;
    variance.sqrt()
}

/// Read a CSV file and compute the stddev of the specified column
fn calculate_stddev(filepath: &str, column_name: &str) -> Result<f64> {
    let mut reader = csv::Reader::from_path(filepath).context("Failed to open CSV file")?; // Context provides better error reporting
    let headers = reader.headers().context("Failed to read CSV headers")?;
    let column_index = headers
        .iter()
        .position(|header| header == column_name)
        .context("Column name not found")?;

    let column_data: Vec<f64> = reader
        .records()
        .filter_map(|result| {
            result.ok().and_then(|record| {
                record
                    .get(column_index)
                    .and_then(|field| field.parse::<f64>().ok())
            })
        })
        .collect();

    Ok(stddev(&column_data))
}

/// Command-line arguments parser using `clap`
#[derive(Parser)]
#[command(name = "CSV StdDev")]
#[command(about = "Calculate standard deviation of a column in a CSV file", long_about = None)]
struct Cli {
    /// Path to the CSV file
    filepath: String,

    /// Name of the column
    column_name: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    // Check if file exists
    fs::metadata(&cli.filepath).context("File does not exist")?;

    let result = calculate_stddev(&cli.filepath, &cli.column_name)
        .context("Failed to calculate standard deviation")?;

    println!(
        "Standard deviation of column '{}': {}",
        cli.column_name, result
    );

    Ok(())
}
