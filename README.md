# Reflink based File/Directory Snapshots

This tool works only if the XFS filesystem is created with the reflink support. For example,

```
$ mkfs.xfs -b size=4096 -m reflink=1,crc=1 /dev/sdb
```

## Create a File or Directory Snapshot.

```
reflink-snapshot create ROOT_DIR PATH@SNAPNAME
```

Example: File Snapshot

```
$ reflink-snapshot create /mnt/data photos/2021/my-awesome-photo.jpeg@s1
Snapshot created successfully!
```

Example: Directory Snapshot

```
$ reflink-snapshot create /mnt/data photos/2021@s1
Snapshot created successfully!
```

## List Snapshots

```
reflink-snapshot list ROOT_DIR
reflink-snapshot list ROOT_DIR PATH
```

Example:

```
$ reflink-snapshot list /mnt/data
photos/2021@s1 (directory)
photos/2021/my-awesome-photo.jpeg@s1  (file)
$
$ reflink-snapshot list /mnt/data photos/2021/my-awesome-photo.jpeg
photos/2021/my-awesome-photo.jpeg@s1  (file)
```

## Delete a Snapshot

```
reflink-snapshot delete ROOT_DIR PATH@SNAP_NAME
```

```
$ reflink-snapshot delete /mnt/data photos/2021/my-awesome-photo.jpeg@s1
Snapshot deleted successfully!
```

## Rollback a Snapshot

```
reflink-snapshot rollback ROOT_DIR PATH@SNAP_NAME
```

```
$ reflink-snapshot rollback /mnt/data photos/2021/my-awesome-photo.jpeg@s1
Snapshot rollback successful!
```

## Mount a Snapshot

```
reflink-snapshot mount ROOT_DIR PATH@SNAP_NAME MOUNTPOINT
```

Directory Snapshot

```
$ mkdir /mnt/photos_2021@s1
$ reflink-snapshot mount /mnt/data photos/2021@s1 /mnt/photos_2021@s1
```

File Snapshot

```
$ touch /mnt/2021_my-awesome-photo@s1.jpeg
$ reflink-snapshot mount /mnt/data photos/2021/my-awesome-photo.jpeg@s1 /mnt/2021_my-awesome-photo@s1.jpeg
```
