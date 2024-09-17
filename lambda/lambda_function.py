import json
import boto3
import os

SECURITYGROUPID = os.environ["SGID"]

PORTS = [22, 3000, 1883, 8883, 8086]

client = boto3.client("ec2")


def lambda_handler(event, context):
    if "current_ip" in event:
        sgrules = client.describe_security_group_rules(
            Filters=[
                {
                    "Name": "group-id",
                    "Values": [
                        SECURITYGROUPID,
                    ],
                },
            ]
        )

        for port in PORTS:
            for sgrule in sgrules["SecurityGroupRules"]:
                if sgrule["FromPort"] == port and sgrule["ToPort"] == port and "CidrIpv4" in sgrule:
                    client.revoke_security_group_ingress(GroupId=SECURITYGROUPID, CidrIp=sgrule["CidrIpv4"], IpProtocol="tcp", FromPort=port, ToPort=port)

            client.authorize_security_group_ingress(GroupId=SECURITYGROUPID, IpProtocol="tcp", FromPort=port, ToPort=port, CidrIp=f"{event['current_ip']}/32")

    if "current_ipv6" in event:
        sgrules = client.describe_security_group_rules(
            Filters=[
                {
                    "Name": "group-id",
                    "Values": [
                        SECURITYGROUPID,
                    ],
                },
            ]
        )

        for port in PORTS:
            for sgrule in sgrules["SecurityGroupRules"]:
                if sgrule["FromPort"] == port and sgrule["ToPort"] == port and "CidrIpv6" in sgrule:
                    client.revoke_security_group_ingress(
                        GroupId=SECURITYGROUPID,
                        IpPermissions=[
                            {
                                "FromPort": port,
                                "IpProtocol": "tcp",
                                "Ipv6Ranges": [
                                    {
                                        "CidrIpv6": event["current_ipv6"],
                                    },
                                ],
                                "ToPort": port,
                            },
                        ],
                    )

            client.authorize_security_group_ingress(
                GroupId=SECURITYGROUPID,
                IpPermissions=[
                    {
                        "FromPort": port,
                        "IpProtocol": "tcp",
                        "Ipv6Ranges": [
                            {
                                "CidrIpv6": event["current_ipv6"],
                            },
                        ],
                        "ToPort": port,
                    },
                ],
            )

    return {"statusCode": 200, "body": json.dumps("Security Group updated!")}
