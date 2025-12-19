#!/usr/bin/env python3
"""
AWS Tag Audit Script

This script audits AWS resources for tag compliance, focusing on high-cost resources
like ECS, CloudWatch, NAT Gateways, and Load Balancers.

Usage:
    python tag-audit.py --region us-east-1 --output audit-report.csv
"""

import boto3
import csv
import json
import argparse
from datetime import datetime
from typing import List, Dict, Any
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class TagAuditor:
    def __init__(self, region: str = 'us-east-1'):
        self.region = region
        self.required_tags = ['Environment', 'Owner', 'CostCenter', 'Application']
        self.session = boto3.Session()
        
    def check_compliance(self, tags: Dict[str, str]) -> Dict[str, Any]:
        """Check if resource has all required tags"""
        missing_tags = []
        for required_tag in self.required_tags:
            if required_tag not in tags or not tags[required_tag].strip():
                missing_tags.append(required_tag)
                
        return {
            'compliant': len(missing_tags) == 0,
            'missing_tags': missing_tags,
            'compliance_score': (len(self.required_tags) - len(missing_tags)) / len(self.required_tags)
        }
    
    def audit_ecs_resources(self) -> List[Dict[str, Any]]:
        """Audit ECS clusters and services"""
        logger.info("Auditing ECS resources...")
        ecs = self.session.client('ecs', region_name=self.region)
        results = []
        
        try:
            # Audit clusters
            clusters_response = ecs.list_clusters()
            cluster_arns = clusters_response.get('clusterArns', [])
            
            for cluster_arn in cluster_arns:
                try:
                    tags_response = ecs.list_tags_for_resource(resourceArn=cluster_arn)
                    tags = {tag['key']: tag['value'] for tag in tags_response.get('tags', [])}
                    
                    compliance = self.check_compliance(tags)
                    results.append({
                        'ResourceType': 'ECS::Cluster',
                        'ResourceId': cluster_arn.split('/')[-1],
                        'ResourceArn': cluster_arn,
                        'Region': self.region,
                        'Compliant': compliance['compliant'],
                        'ComplianceScore': f"{compliance['compliance_score']:.2%}",
                        'MissingTags': ','.join(compliance['missing_tags']),
                        'ExistingTags': json.dumps(tags, separators=(',', ':')),
                        'TagCount': len(tags)
                    })
                    
                    # Audit services in this cluster
                    services_response = ecs.list_services(cluster=cluster_arn)
                    service_arns = services_response.get('serviceArns', [])
                    
                    for service_arn in service_arns:
                        try:
                            service_tags_response = ecs.list_tags_for_resource(resourceArn=service_arn)
                            service_tags = {tag['key']: tag['value'] for tag in service_tags_response.get('tags', [])}
                            
                            service_compliance = self.check_compliance(service_tags)
                            results.append({
                                'ResourceType': 'ECS::Service',
                                'ResourceId': service_arn.split('/')[-1],
                                'ResourceArn': service_arn,
                                'Region': self.region,
                                'Compliant': service_compliance['compliant'],
                                'ComplianceScore': f"{service_compliance['compliance_score']:.2%}",
                                'MissingTags': ','.join(service_compliance['missing_tags']),
                                'ExistingTags': json.dumps(service_tags, separators=(',', ':')),
                                'TagCount': len(service_tags)
                            })
                        except Exception as e:
                            logger.error(f"Error auditing ECS service {service_arn}: {e}")
                            
                except Exception as e:
                    logger.error(f"Error auditing ECS cluster {cluster_arn}: {e}")
                    
        except Exception as e:
            logger.error(f"Error listing ECS clusters: {e}")
            
        return results
    
    def audit_cloudwatch_resources(self) -> List[Dict[str, Any]]:
        """Audit CloudWatch log groups and dashboards"""
        logger.info("Auditing CloudWatch resources...")
        logs = self.session.client('logs', region_name=self.region)
        cloudwatch = self.session.client('cloudwatch', region_name=self.region)
        results = []
        
        # Audit log groups
        try:
            paginator = logs.get_paginator('describe_log_groups')
            for page in paginator.paginate():
                for log_group in page.get('logGroups', []):
                    log_group_name = log_group['logGroupName']
                    
                    try:
                        tags_response = logs.list_tags_log_group(logGroupName=log_group_name)
                        tags = tags_response.get('tags', {})
                        
                        compliance = self.check_compliance(tags)
                        results.append({
                            'ResourceType': 'Logs::LogGroup',
                            'ResourceId': log_group_name,
                            'ResourceArn': f"arn:aws:logs:{self.region}:*:log-group:{log_group_name}",
                            'Region': self.region,
                            'Compliant': compliance['compliant'],
                            'ComplianceScore': f"{compliance['compliance_score']:.2%}",
                            'MissingTags': ','.join(compliance['missing_tags']),
                            'ExistingTags': json.dumps(tags, separators=(',', ':')),
                            'TagCount': len(tags)
                        })
                    except Exception as e:
                        logger.error(f"Error auditing log group {log_group_name}: {e}")
                        
        except Exception as e:
            logger.error(f"Error listing CloudWatch log groups: {e}")
        
        # Audit dashboards
        try:
            dashboards_response = cloudwatch.list_dashboards()
            for dashboard in dashboards_response.get('DashboardEntries', []):
                dashboard_name = dashboard['DashboardName']
                
                try:
                    tags_response = cloudwatch.list_tags_for_resource(
                        ResourceARN=f"arn:aws:cloudwatch:{self.region}:*:dashboard/{dashboard_name}"
                    )
                    tags = {tag['Key']: tag['Value'] for tag in tags_response.get('Tags', [])}
                    
                    compliance = self.check_compliance(tags)
                    results.append({
                        'ResourceType': 'CloudWatch::Dashboard',
                        'ResourceId': dashboard_name,
                        'ResourceArn': f"arn:aws:cloudwatch:{self.region}:*:dashboard/{dashboard_name}",
                        'Region': self.region,
                        'Compliant': compliance['compliant'],
                        'ComplianceScore': f"{compliance['compliance_score']:.2%}",
                        'MissingTags': ','.join(compliance['missing_tags']),
                        'ExistingTags': json.dumps(tags, separators=(',', ':')),
                        'TagCount': len(tags)
                    })
                except Exception as e:
                    logger.error(f"Error auditing dashboard {dashboard_name}: {e}")
                    
        except Exception as e:
            logger.error(f"Error listing CloudWatch dashboards: {e}")
            
        return results
    
    def audit_networking_resources(self) -> List[Dict[str, Any]]:
        """Audit NAT Gateways and Load Balancers"""
        logger.info("Auditing networking resources...")
        ec2 = self.session.client('ec2', region_name=self.region)
        elbv2 = self.session.client('elbv2', region_name=self.region)
        results = []
        
        # Audit NAT Gateways
        try:
            nat_gateways_response = ec2.describe_nat_gateways()
            for nat_gateway in nat_gateways_response.get('NatGateways', []):
                nat_gateway_id = nat_gateway['NatGatewayId']
                tags = {tag['Key']: tag['Value'] for tag in nat_gateway.get('Tags', [])}
                
                compliance = self.check_compliance(tags)
                results.append({
                    'ResourceType': 'EC2::NatGateway',
                    'ResourceId': nat_gateway_id,
                    'ResourceArn': f"arn:aws:ec2:{self.region}:*:natgateway/{nat_gateway_id}",
                    'Region': self.region,
                    'Compliant': compliance['compliant'],
                    'ComplianceScore': f"{compliance['compliance_score']:.2%}",
                    'MissingTags': ','.join(compliance['missing_tags']),
                    'ExistingTags': json.dumps(tags, separators=(',', ':')),
                    'TagCount': len(tags)
                })
                
        except Exception as e:
            logger.error(f"Error auditing NAT Gateways: {e}")
        
        # Audit Application Load Balancers
        try:
            load_balancers_response = elbv2.describe_load_balancers()
            for lb in load_balancers_response.get('LoadBalancers', []):
                lb_arn = lb['LoadBalancerArn']
                lb_name = lb['LoadBalancerName']
                
                try:
                    tags_response = elbv2.describe_tags(ResourceArns=[lb_arn])
                    tags = {}
                    for tag_description in tags_response.get('TagDescriptions', []):
                        tags.update({tag['Key']: tag['Value'] for tag in tag_description.get('Tags', [])})
                    
                    compliance = self.check_compliance(tags)
                    results.append({
                        'ResourceType': 'ElasticLoadBalancingV2::LoadBalancer',
                        'ResourceId': lb_name,
                        'ResourceArn': lb_arn,
                        'Region': self.region,
                        'Compliant': compliance['compliant'],
                        'ComplianceScore': f"{compliance['compliance_score']:.2%}",
                        'MissingTags': ','.join(compliance['missing_tags']),
                        'ExistingTags': json.dumps(tags, separators=(',', ':')),
                        'TagCount': len(tags)
                    })
                except Exception as e:
                    logger.error(f"Error auditing load balancer {lb_name}: {e}")
                    
        except Exception as e:
            logger.error(f"Error auditing Load Balancers: {e}")
            
        return results
    
    def generate_report(self, output_file: str = 'tag_audit_report.csv') -> None:
        """Generate comprehensive audit report"""
        logger.info(f"Starting tag audit for region: {self.region}")
        all_results = []
        
        # Collect results from all resource types
        all_results.extend(self.audit_ecs_resources())
        all_results.extend(self.audit_cloudwatch_resources())
        all_results.extend(self.audit_networking_resources())
        
        # Write to CSV
        if all_results:
            fieldnames = [
                'ResourceType', 'ResourceId', 'ResourceArn', 'Region',
                'Compliant', 'ComplianceScore', 'MissingTags', 'TagCount', 'ExistingTags'
            ]
            
            with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()
                for result in all_results:
                    writer.writerow(result)
        
        # Generate summary statistics
        self.print_summary(all_results, output_file)
    
    def print_summary(self, results: List[Dict[str, Any]], output_file: str) -> None:
        """Print audit summary statistics"""
        if not results:
            logger.warning("No resources found to audit")
            return
            
        total_resources = len(results)
        compliant_resources = sum(1 for r in results if r['Compliant'])
        compliance_rate = (compliant_resources / total_resources) * 100 if total_resources > 0 else 0
        
        # Resource type breakdown
        resource_types = {}
        for result in results:
            resource_type = result['ResourceType']
            if resource_type not in resource_types:
                resource_types[resource_type] = {'total': 0, 'compliant': 0}
            resource_types[resource_type]['total'] += 1
            if result['Compliant']:
                resource_types[resource_type]['compliant'] += 1
        
        # Most common missing tags
        missing_tags_count = {}
        for result in results:
            if result['MissingTags']:
                for tag in result['MissingTags'].split(','):
                    missing_tags_count[tag] = missing_tags_count.get(tag, 0) + 1
        
        print("\n" + "="*60)
        print("AWS TAG AUDIT SUMMARY")
        print("="*60)
        print(f"Audit Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Region: {self.region}")
        print(f"Required Tags: {', '.join(self.required_tags)}")
        print(f"Report File: {output_file}")
        print()
        
        print("OVERALL COMPLIANCE:")
        print(f"  Total Resources: {total_resources}")
        print(f"  Compliant Resources: {compliant_resources}")
        print(f"  Non-Compliant Resources: {total_resources - compliant_resources}")
        print(f"  Overall Compliance Rate: {compliance_rate:.1f}%")
        print()
        
        print("COMPLIANCE BY RESOURCE TYPE:")
        for resource_type, stats in sorted(resource_types.items()):
            compliance_pct = (stats['compliant'] / stats['total']) * 100
            print(f"  {resource_type}:")
            print(f"    Total: {stats['total']}, Compliant: {stats['compliant']} ({compliance_pct:.1f}%)")
        print()
        
        if missing_tags_count:
            print("MOST COMMON MISSING TAGS:")
            for tag, count in sorted(missing_tags_count.items(), key=lambda x: x[1], reverse=True):
                print(f"  {tag}: {count} resources")
        
        print("\n" + "="*60)
        
        # Recommendations
        if compliance_rate < 95:
            print("\nRECOMMENDations:")
            print("- Use AWS Tag Editor for bulk tagging operations")
            print("- Implement AWS Config rules for ongoing compliance monitoring")
            print("- Set up AWS Organizations tag policies to prevent untagged resources")
            print("- Consider automated tagging through Terraform or Lambda functions")

def main():
    parser = argparse.ArgumentParser(description='Audit AWS resources for tag compliance')
    parser.add_argument('--region', default='us-east-1', help='AWS region to audit (default: us-east-1)')
    parser.add_argument('--output', default='tag_audit_report.csv', help='Output CSV file (default: tag_audit_report.csv)')
    parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        auditor = TagAuditor(region=args.region)
        auditor.generate_report(output_file=args.output)
    except Exception as e:
        logger.error(f"Audit failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
