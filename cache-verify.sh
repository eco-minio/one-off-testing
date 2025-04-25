#!/bin/bash
# run functional tests for mincache
# This script tests basic functionality of the cache. It includes a put, put object tag, update object tag, and delete. For each operation, one or more Statcalls are used to verify whether the cache headers have been set.
# The test is self-contained, does not require an existing MinIO instance, although it does require the MinIO binary to be installed.
echo 'Make sure you are sending audit events to an external webhook'

#delete exisg
rm -rf /tmp/cache/

# start temporary server for cache testing
CI=on MINIO_AUDIT_WEBHOOK_ENABLE=on MINIO_AUDIT_WEBHOOK_ENDPOINT="http://127.0.0.1:8888" MINIO_ROOT_USER=minioadmin MINIO_ROOT_PASSWORD=minioadmin MINIO_LICENSE=~/Downloads/minio.license MINIO_CACHE_ENABLE=on MINIO_CACHE_SIZE="1GB" MINIO_API_ODIRECT=write nohup minio server --address :10001 --console-address :10002 -S /var/log/ /tmp/cache & 

#give the server time to initialize
sleep 5

# Set alias
mc --insecure alias set cache http://localhost:10001  minioadmin minioadmin



#% Create bucket 
mc --insecure mb cache/cache-tests

#% Create anonymous policy for cache  bucket
cat <<EOF > /tmp/anonymous-policy.json
{
 "Statement": [
  {
   "Action": [
    "s3:ListBucket",
    "s3:ListBucketMultipartUploads",
    "s3:GetBucketLocation"
   ],
   "Effect": "Allow",
   "Principal": {
    "AWS": [
     "*"
    ]
   },
   "Resource": [
    "arn:aws:s3:::cache-tests"
   ]
  },
  {
   "Action": [
    "s3:AbortMultipartUpload",
    "s3:DeleteObject",
    "s3:GetObject",
    "s3:ListMultipartUploadParts",
    "s3:PutObjectTagging",
    "s3:PutObject"
   ],
   "Effect": "Allow",
   "Principal": {
    "AWS": [
     "*"
    ]
   },
 "Resource": [
    "arn:aws:s3:::cache-tests/*"
   ]
  }
 ],
 "Version": "2012-10-17"
}
EOF

# Create initial tags xml
cat <<EOF > /tmp/tags1
<?xml version="1.0" encoding="UTF-8"?>
<Tagging xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
   <TagSet>
      <Tag>
         <Key>key1</Key>
         <Value>value1</Value>
	 <Key>key2</Key>
         <Value>value2</Value>
      </Tag>
   </TagSet>
</Tagging>
EOF

# Create updated tags xml
cat <<EOF > /tmp/tags2
<?xml version="1.0" encoding="UTF-8"?>
<Tagging xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
   <TagSet>
      <Tag>
         <Key>key1</Key>
         <Value>value3</Value>
         <Key>key2</Key>
         <Value>value4</Value>
      </Tag>
   </TagSet>
</Tagging>
EOF

#Apply anonymous policy
mc --insecure anonymous set-json /tmp/anonymous-policy.json cache/cache-tests/




#% PUT file
curl -d "cache test" -X PUT http://127.0.0.1:10001/cache-tests/testobject

# % first get after initial put
curl -I http://127.0.0.1:10001/cache-tests/testobject

# % second get after initial put
curl -I http://127.0.0.1:10001/cache-tests/testobject

#% set tags

curl -T "/tmp/tags1" -X PUT http://127.0.0.1:10001/cache-tests/testobject?tagging

# %get object after first tag

curl -I http://127.0.0.1:10001/cache-tests/testobject

# %get object second time after first  tag

curl -I http://127.0.0.1:10001/cache-tests/testobject


# %Set new tags 

curl -T "/tmp/tags2" -X PUT http://127.0.0.1:10001/cache-tests/testobject?tagging

# %get after tag update 
curl -I http://127.0.0.1:10001/cache-tests/testobject

# %get again after tag update
curl -I http://127.0.0.1:10001/cache-tests/testobject


# %restart service
mc --insecure admin service restart cache

sleep 5


# % stat object first time after restart
echo "First curl after restart"
curl -I http://127.0.0.1:10001/cache-tests/testobject

# %stat object second time after restart
echo "second curl after restart"
curl -I http://127.0.0.1:10001/cache-tests/testobject


# %delete object

echo "delete after restart"
curl -X DELETE http://127.0.0.1:10001/cache-tests/testobject
# %stat object second time after delete
curl -I http://127.0.0.1:10001/cache-tests/testobject

# leave this sleep in so that the other operations have a change to finish
sleep 5
mc --insecure admin service stop cache




