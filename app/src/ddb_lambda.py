import boto3
import os
import ipaddress
import hashlib
import logging
import json

dynamodb = boto3.client('dynamodb')


def lambda_handler(event, context):
    table = os.environ('DDB_TABLE')
    # Retrieve the IP address from the request metadata
    ip_address = event['requestContext']['http']['sourceIp']

    try:
        # Check if the IP address is valid
        ipaddress.ip_address(ip_address)

        if ip_address:
            # Generate a one-way hash of the IP address
            ip_hash = hashlib.sha256(ip_address.encode()).hexdigest()

            try:
                # Check if the IP address is already in the database
                response = dynamodb.get_item(
                    Key={'IPHash': {'S': ip_hash}},
                    TableName=table
                )

                if 'Item' not in response.keys():
                    # IP hash does not exist, create a new item with VisitorCount initialized to 1
                    dynamodb.put_item(
                        TableName=table,
                        Item={'IPHash': {'S': ip_hash}}
                    )

                else:
                    logging.info('Skipping since item already exists')

            except Exception:
                logging.exception("Error occured while updating")
                return {
                    'statusCode': 400,
                    'body': json.dumps('Something went wrong!')
                }
        else:
            logging.info("No IP found.")

    except ValueError:
        logging.error('Invalid IP address: {}'.format(ip_address))

    response = dynamodb.scan(
        # Scan the table to get the number of unique visitors
        TableName=table
    )

    if "Items" in response.keys():
        # Return the number of unique visitors
        return {
            'statusCode': 200,
            'body': json.dumps(len(response['Items']))
        }
    else:
        return {
            'statusCode': 200,
            'body': 0
        }
