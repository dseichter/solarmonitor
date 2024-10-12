# solarmonitor

Services to monitor my solar system

After receiving my solar system, my target is to monitor my solar system (and in future other components). Instead of having a server at my network at home, I trust in AWS. Therefore I want to use AWS resources, I can use in general to be most flexible.

# Table of Contents

- [solarmonitor](#solarmonitor)
  - [Components](#components)
  - [The challenges](#the-challenges)
    - [Updating the security group in AWS](#updating-the-security-group-in-aws)
    - [Resources](#resources)
    - [Retrieving messages](#retrieving-messages)
    - [Storing the messages](#storing-the-messages)
    - [Dashboard](#dashboard)
  - [The solution](#the-solution)
    - [Detailed overview](#detailed-overview)
  - [Implementation](#implementation)
  - [Raspberry PI](#raspberry-pi)
  - [Lambda](#lambda)
  - [MQTT](#mqtt)
  - [Anker Solix E1600](#anker-solix-e1600)
  - [InfluxDB](#influxdb)

## Components

The following is the list of my components, I decided to use

* Raspberry Pi
* OpenDTU (replacement of Hoymiles DTU)
* Hoymiles inverter HMS-1600-4T
* Anker Solix Battery E1600
* 4 solar panels

![grafana-dashboard](grafana-dashboard.png)

## The challenges

How can I connect my local components to AWS without VPN and how can I secure it. The other challenge is being most flexible, so that my services can handle more and more resources in a cost effective way.

I do not want to automate my home, therefore there is no active channel needed from AWS to local network.

### Updating the security group in AWS

To protect resources in AWS, you can use Security Groups. Using the management console, you can select your current IP address, so that only your network can access them. To do this, I want to use the Raspberry PI. Every minute it should be checked, if my current local IP has been changed. If yes, update the Security Group.

### Resources

I want to split all services into separate instances. That means, every services has its own resources, I can increase/decrease them and also having a kind of high availability. EC2 is the way to go for this project.

### Retrieving messages

OpenDTU supports MQTT. Instead of using AWS IoT, I decided to use the most recommended solution and provide a MQTT broker aka mosquitto. Simple in the setup, needs less resources and well documented.

### Storing the messages

In combination of telegraf, influxdb was the choice. To be honest, at the first time, I installed both on one instance, but now also telegraf has its own instance. So I am independent if something will break at one component.

### Dashboard

Only Grafana was in the evaluation, because there are good shared Dashboards, I am able to use and extend. On the other side, I also want to learn more about the capabilities of Grafana :smile:.

## The solution

In this graph, I want to show you, how it looks like.

![architecture](architecture.png)

### Detailed overview

| Task/Service | Location | Instance | Notes |
| -------          | -------- | -------- | ----- |
| Update public IP | local | Raspberry PI | Check every minute my public IP |
| OpenDTU          | local | Appliance    | connected to Hoymiles inverter |
| MQTT             | AWS   | t4g.nano     | retrieves MQTT messages only from local network |
|                  |       |              | runs [solix2influxdb](https://github.com/dseichter/solix2influxdb) |
| Telegraf         | AWS   | t3a.nano     | read, process and store to InfluxDB (see later, why t3a) |
| InfluxDB         | AWS   | t4g.micro    | Time series database |
| Grafana          | AWS   | t4g.micro    | Dashboard |

---

# Implementation

Some configuration files I have added to this repository. Feel free to use them. I will add more and more information and update this repository, because I also use it as my backup of my own configuration (except passwords :smile:). Using IPv6 will save you money because you do not need to pay for the public IPv4 addresses.

How to setup an EC2 is well documented by AWS. Probably I will provide a terraform script to automate it.

## Raspberry PI

Run the script [solar_update_sg.sh](/raspberrypi/solar_update_sg.sh) using cron every minute (or any other interval). My provided script is using my AVM FritzBox with TR069 enabled.

Instead of the risk of running into a ratelimit by using public services like [ipfy.org](https://www.ipify.org/), your local router does not have one.

The script requests your publick IPv4 and IPv6 address. If there was a change, it will invoke a AWS Lambda by using predefined credentials. Those credentials can be set up by configuring the aws cli or add them into your copy of the script.

To be most secure, create a special IAM user, which is only allowed to invoke this Lambda. An example policy good be:

```JSON
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction",
                "lambda:InvokeAsync"
            ],
            "Resource": "arn:aws:lambda:eu-central-1:123456789012:function:solar_updateSecurityGroup"
        }
    ]
}
```

## Lambda

The provided Lambda code ([lambda_function.py](/lambda/lambda_function.py)) you can use to update your security group.
Use Python 3.12 as runtime and create the environment variable `SGID` and provide the ID the security group, you have created for your solar environment.

The lambda will revoke at first each provided port and grant after that the permission for your provided IP addresses. If you have changed your ports, please adjust the script.

## MQTT

Create an instance using Ubuntu (latest), choose smallest instance size, like t4g.nano (or t3a, t3,...). Be sure you have added this EC2 instance to your security group of your solar environment.

Run `sudo apt install mosquitto`

Create a config file at `/etc/mosquitto/conf.d/`, e.g. solar.conf and add at least the following content:

```yaml
listener 1883
allow_anonymous true
```

Securing it with credentials, encrpytion, etc. will follow. Because of only you are able to connect to this instance, security can be updated later.

Be sure, mosquitto will started automatically (systemctl enable mosquitto) and it listens on all interfaces (IPv4 and IPv6) at the given port 1883.

### Anker Solix E1600

To add also the data from my Anker Solix E1600 I have created another repository [solix2influxdb](https://github.com/dseichter/solix2influxdb). This will be able to send the data directly to an influxdb bucket.

## InfluxDB

Create an instance using Ubuntu, choose a small instance size, like t4g.micro (or t3a, t3,...). Be sure you have added this EC2 instance to your security group.

Follow the installation instructions [Install InfluxDB](https://docs.influxdata.com/influxdb/v2/install/)

Also proceed the setup of InfluxDB like described at [Setup InfluxDB](https://docs.influxdata.com/influxdb/v2/get-started/setup/?t=Set+up+with+the+CLI).

Be sure, InfluxDB will start automatically.

For telegraf, create a token with access to the bucket within InfluxDB. Note, that you should set up retention period to 0 by creating the bucket, e.g. `hoymiles`.

Store this token at a secure place, you will need it later.

## Telegraf

Create an instance using Ubuntu, choose smallest instance size, like t3a.nano (t3,...). Be sure you have added this EC2 instance to your security group. Also be sure, to use **x86** and not ARM. The provided package of telegraf will fail unfortunately on ARM architecture at AWS.

Follow the installation instructions [Install Telegraf](https://docs.influxdata.com/telegraf/v1/install/)

After installing, create a configuration file in `/etc/telegraf/telegraf.d`. An example file, you will find in this repository [here](/telegraf/etc/telegraf/telegraf.d/hoymiles.conf).

You have to adjust the domain, add the token, you have created see influxdb. 

Only **after** you have created and started mosquitto and influxdb, telegraf will be able start without any issue!

## Grafana

Create an instance using Ubuntu, choose smallest instance size, like t4g.nano (or t3a, t3,...). Be sure you have added this EC2 instance to your security group.

Install Grafana by following the [Install grafana on Debian or Ubuntu](https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/) instructions. Change initial password and create a Datasource to InfluxDB (you need the token again).

I provide my [Dashboard](/grafana/openDTU%20[Flux]-1726603045824.json), which is an edit of https://grafana.com/grafana/dashboards/18819-opendtu-flux/.

# Feedback

You are welcome to provide feedback.

## Next steps

I want to provide a level of security by encrypting everything. This will be done using [Let's Encrypt](https://letsencrypt.org) which needs to be automated. Using this, I also have to open the Security Group for a short period of time to other hosts to verify the certificate. It remains exciting :smile: