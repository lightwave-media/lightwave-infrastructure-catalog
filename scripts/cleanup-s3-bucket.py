#!/usr/bin/env python3
import boto3
import sys

def delete_all_versions(bucket_name, profile_name):
    """Delete all object versions and delete markers from an S3 bucket."""
    session = boto3.Session(profile_name=profile_name)
    s3 = session.client('s3')

    print(f"Deleting all versions and delete markers from {bucket_name}...")

    # Paginate through all versions
    paginator = s3.get_paginator('list_object_versions')
    pages = paginator.paginate(Bucket=bucket_name)

    delete_count = 0
    for page in pages:
        # Delete versions
        if 'Versions' in page:
            for version in page['Versions']:
                s3.delete_object(
                    Bucket=bucket_name,
                    Key=version['Key'],
                    VersionId=version['VersionId']
                )
                delete_count += 1
                print(f"  Deleted version: {version['Key']} ({version['VersionId']})")

        # Delete delete markers
        if 'DeleteMarkers' in page:
            for marker in page['DeleteMarkers']:
                s3.delete_object(
                    Bucket=bucket_name,
                    Key=marker['Key'],
                    VersionId=marker['VersionId']
                )
                delete_count += 1
                print(f"  Deleted marker: {marker['Key']} ({marker['VersionId']})")

    print(f"✅ Deleted {delete_count} objects/versions")
    return delete_count

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 cleanup-s3-bucket.py <bucket-name> <profile-name>")
        sys.exit(1)

    bucket = sys.argv[1]
    profile = sys.argv[2]

    try:
        delete_all_versions(bucket, profile)
        print(f"\n✅ Bucket {bucket} is now empty and can be deleted")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)
