use std::{collections::HashMap, fs::File};

use anyhow::{Context, Result}; // Import Result and Context from anyhow
use csv::ReaderBuilder;
use oohcore::spill_and_runtime::DataPoint;

const RESULTS_DIR: &str = "./benchmark/results/ex7";
const JOIN_BUFFER_SIZES: &[&str] = &["384KB", "768KB", "1MB", "2MB", "3MB"];

type SpeedupMap = HashMap<String, f64>;

fn main() -> Result<()> {
    for join_buffer_size in JOIN_BUFFER_SIZES {
        println!("-----------------------------------------------");
        println!("Experiment join_buffer_size: {join_buffer_size}");

        let baseline_filename = format!("{}/baseline_{}.csv", RESULTS_DIR, join_buffer_size);
        let baseline_datapoints = read_csv_file(&baseline_filename)?;
        println!("  Baseline rows: {}", baseline_datapoints.len());

        let oohj_filename = format!("{}/oohj-optimism_{}.csv", RESULTS_DIR, join_buffer_size);
        let oohj_datapoints = read_csv_file(&oohj_filename)?;
        println!("  OOHJ rows: {}", oohj_datapoints.len());

        let speedup_map = calculate_speedup(&baseline_datapoints, &oohj_datapoints);

        apex(&speedup_map);
    }
    Ok(())
}

fn read_csv_file(filename: &str) -> Result<Vec<DataPoint>> {
    let file = File::open(filename).context("Failed to open file")?;
    let mut rdr = ReaderBuilder::new().has_headers(true).from_reader(file);
    let mut data_points = Vec::new();

    for result in rdr.deserialize() {
        let data_point: DataPoint = result.context("Failed to deserialize data")?;
        data_points.push(data_point);
    }

    Ok(data_points)
}

fn calculate_speedup(baseline: &Vec<DataPoint>, oohj: &Vec<DataPoint>) -> SpeedupMap {
    let baseline_mean: f64 =
        baseline.iter().map(|dp| dp.duration_s).sum::<f64>() / baseline.len() as f64;

    let mut optimism_map: HashMap<String, (f64, usize)> = HashMap::new();
    for dp in oohj {
        let rounded_optimism = (dp.optimism_level * 100.0).round() / 100.0;
        let key = rounded_optimism.to_string();

        optimism_map
            .entry(key)
            .and_modify(|e| {
                e.0 += dp.duration_s;
                e.1 += 1;
            })
            .or_insert((dp.duration_s, 1));
    }

    let mut speedup_map: HashMap<String, f64> = HashMap::new();
    for (optimism_level, (sum_duration, count)) in optimism_map {
        let oohj_mean = sum_duration / count as f64;
        let speedup = baseline_mean / oohj_mean;
        speedup_map.insert(optimism_level, speedup);
    }

    speedup_map
}

fn apex(speedup_map: &SpeedupMap) {
    if let Some((optimism_level, &max_speedup)) = speedup_map
        .iter()
        .max_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
    {
        println!(
            "  Speedup Apex: optimism_level: {}, speedup: {}",
            optimism_level, max_speedup
        );
    } else {
        println!("  No data points found to calculate apex.");
    }
}
