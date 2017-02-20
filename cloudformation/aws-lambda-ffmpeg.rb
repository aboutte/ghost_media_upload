#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'Resizes a video'

  parameter 'SourceBucketName',
            :Type => 'String',
            :Description => 'The S3 source bucket',
            :Default => 'mahryboutte.com-queue'

  parameter 'DestinationBucketName',
            :Type => 'String',
            :Description => 'The S3 source bucket',
            :Default => 'mahryboutte.com-processed'

  parameter 'LambdaS3Bucket',
            :Type => 'String',
            :Description => 'The S3 bucket in which the lambda function code is stored'
            :Default => 'aboutte-lambda'

  parameter 'LambdaS3Key',
            :Type => 'String',
            :AllowedPattern => '.*\\.zip',
            :Description => 'The S3 key for the lambda function code'
            :Default => 'aws-lambda-ffmpeg.zip'

  resource 'ExecutionRole', :Type => 'AWS::IAM::Role', :Properties => {
      :AssumeRolePolicyDocument => {
          :Version => '2012-10-17',
          :Statement => [
              {
                  :Effect => 'Allow',
                  :Principal => { :Service => [ 'lambda.amazonaws.com' ] },
                  :Action => [ 'sts:AssumeRole' ],
              },
          ],
      },
      :Path => '/',
      :Policies => [
          {
              :PolicyName => 'ExecutionRolePolicy',
              :PolicyDocument => {
                  :Version => '2012-10-17',
                  :Statement => [
                      {
                          :Effect => 'Allow',
                          :Action => [ 'logs:*' ], # TODO
                          :Resource => [ 'arn:aws:logs:*:*:*' ],
                      },
                      {
                          :Effect => 'Allow',
                          :Action => 's3:GetObject',
                          :Resource => join('', 'arn:aws:s3:::', ref('SourceBucketName'), '/*'),
                      },
                      {
                          :Effect => 'Allow',
                          :Action => 's3:PutObject',
                          :Resource => join('', 'arn:aws:s3:::', ref('DestinationBucketName'), '/*'),
                      },
                  ],
              },
          },
      ],
  }

  resource 'Lambda', :Type => 'AWS::Lambda::Function', :DependsOn => [ 'ExecutionRole' ], :Properties => {
      :Code => {
          :S3Bucket => ref('LambdaS3Bucket'),
          :S3Key => ref('LambdaS3Key'),
      },
      :Role => get_att('ExecutionRole', 'Arn'),
      :Timeout => 60,
      :Handler => 'aws/index.handler',
      :Runtime => 'nodejs4.3',
      :MemorySize => 1536,
  }

  resource 'LambdaPermission', :Type => 'AWS::Lambda::Permission', :DependsOn => [ 'Lambda' ], :Properties => {
      :Action => 'lambda:invokeFunction',
      :FunctionName => get_att('Lambda', 'Arn'),
      :Principal => 's3.amazonaws.com',
      :SourceAccount => aws_account_id,
      :SourceArn => join('', 'arn:aws:s3:::', ref('SourceBucketName')),
  }

  resource 'SourceBucket', :Type => 'AWS::S3::Bucket', :DependsOn => [ 'Lambda' ], :Properties => {
      :BucketName => ref('SourceBucketName'),
      :NotificationConfiguration => {
          :LambdaConfigurations => [
              {
                  :Event => 's3:ObjectCreated:*',
                  :Function => get_att('Lambda', 'Arn'),
              },
          ],
      },
  }

  resource 'DestinationBucket', :Type => 'AWS::S3::Bucket', :Properties => { :BucketName => ref('DestinationBucketName') }

end.exec!
