import argparse
import polars as pl

# Generate ENA download URLs
def generate_ena_links(row):
    acc = row["acc"]
    librarylayout = row["librarylayout"]
    prefix = acc[:6]
    group = f"{acc[-3:]}"  # 046 in ERR13480646
    url_base = f"ftp://ftp.sra.ebi.ac.uk/vol1/fastq/{prefix}/{group}/{acc}"
    
    # Generate URLs based on library layout
    if librarylayout == "PAIRED":
        urls = [
            f"{url_base}/{acc}_1.fastq.gz",
            f"{url_base}/{acc}_2.fastq.gz",
        ]
    else:  # SINGLE
        urls = [f"{url_base}/{acc}.fastq.gz"]
    
    return ";".join(urls)


def main(args):
    sra_prj = args.bioproject

    # Load the SRA metadata, including the library layout field
    sra_metadata = pl.scan_parquet(
        "s3://sra-pub-metadata-us-east-1/sra/metadata/",
        storage_options={"skip_signature": "true"},
    ).select(["acc", "bioproject", "librarylayout"])

    # Filter metadata for the specified Bioproject
    filtered_metadata = sra_metadata.filter(pl.col("bioproject") == sra_prj).collect()

    # Convert to Pandas for easier row-wise processing => should be able to do this in polars...
    filtered_df = filtered_metadata.to_pandas()

    # Apply the function to generate URLs
    filtered_df["url"] = filtered_df.apply(generate_ena_links, axis=1)

    # Add other required columns
    filtered_df["name"] = filtered_df["acc"]
    filtered_df["moltype"] = "DNA"
    filtered_df["md5sum"] = ""
    filtered_df["range"] = ""
    filtered_df["download_filename"] = filtered_df["acc"] + ".fastq.gz"
    filtered_df.rename(columns={"acc": "accession"}, inplace=True)

    # Write directly to a CSV file
    filtered_df.to_csv(
        args.output,
        columns=["accession", "name", "moltype", "md5sum", "download_filename", "url", "range"],
        sep=",",
        index=False,
    )

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Generate ENA download links for a specific Bioproject ID.")
    p.add_argument("-p", "--bioproject", required=True, help="SRA Bioproject ID (e.g., PRJEB74559)")
    p.add_argument("-o", "--output", required=True, help="Output CSV file path")
    args = p.parse_args()
    main(args)
