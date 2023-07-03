"""
Create a lambda function that will be triggered by AWS API Gateway that accepts requests from my web app.
This function will be responsible for handling requests which retrieve and update the visitor count in a DynamoDB database.
Function has to only count unique visitors. (Hint: check the API Gateway request metadata for the IP address associated with the browser making the API call.
Note: IP addresses may be considered PII (personally-identifying information) in some jurisdictions, so you have consider storing a one-way hash of the address instead
"""

import boto3
import ipaddress
import hashlib
import logging
import json

dynamodb = boto3.client('dynamodb')


def lambda_handler(event, context):

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
                    TableName='VisitorCountTable'
                )

                if 'Item' not in response.keys():
                    # IP hash does not exist, create a new item with VisitorCount initialized to 1
                    dynamodb.put_item(
                        TableName='VisitorCountTable',
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

    response = dynamodb.scan()

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
