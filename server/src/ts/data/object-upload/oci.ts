import { default as Crypto } from "crypto";
import { default as OciCommon } from "oci-common";
import { NoRetryConfigurationDetails } from "oci-common/lib/retrier";
import { default as Oci } from "oci-objectstorage";
import { OciError } from "oci-sdk";

import { Config } from "../../server/config.js";
import { details, ObjectUploader } from "../object-upload.js";

export class OciObjectUploader implements ObjectUploader {
  readonly config;
  readonly details;
  readonly client;
  readonly baseUrl;

  constructor(config: Config.OciObjectUpload) {
    this.config = config;
    this.details = details(config);
    this.client = new Oci.ObjectStorageClient({
      authenticationDetailsProvider:
      new OciCommon.SimpleAuthenticationDetailsProvider(
        config.tenancy,
        config.user,
        config.fingerprint,
        config.privateKey.value,
        config.passphrase?.value ?? null,
        OciCommon.Region.fromRegionId(config.region),
      ),
    });
    this.baseUrl = `https://objectstorage.${config.region}.oraclecloud.com/n/${config.namespace}/b/${config.bucket}/o/`;
  }

  private url(name: string): URL {
    return new URL(name, this.baseUrl);
  }

  async upload(
    originalName: string,
    contentType: string,
    data: Uint8Array,
    metadata?: Record<string, string>,
  ): Promise<URL> {
    const manager = new Oci.UploadManager(this.client);
    const name = this.details.name(originalName, data);
    const md5 = Crypto.createHash("md5");
    md5.update(data);
    try {
      await manager.upload({
        content: { stream: data },
        singleUpload: true,
        requestDetails: {
          namespaceName: this.config.namespace,
          bucketName: this.config.bucket,
          objectName: name,
          contentMD5: md5.digest("base64"),
          contentType,
          ...(this.details.cacheControl !== undefined
            ? { cacheControl: this.details.cacheControl }
            : {}),
          opcMeta: metadata,
          ...(this.details.allowOverwrite ? {} : { ifNoneMatch: "*" }),
          retryConfiguration: NoRetryConfigurationDetails,
        },
      });
    } catch (error) {
      if (
        error instanceof OciError &&
        error.serviceCode === "IfNoneMatchFailed"
      ) {
        return this.url(name);
      } else {
        throw error;
      }
    }
    return this.url(name);
  }

  async delete(url: string): Promise<void> {
    const objectName = url.split("/").at(-1);
    if (objectName === undefined) {
      throw new Error("Malformed URL.");
    }
    await this.client.deleteObject({
      namespaceName: this.config.namespace,
      bucketName: this.config.bucket,
      objectName,
      retryConfiguration: NoRetryConfigurationDetails,
    });
  }
}
