////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation
import Realm
import Realm.Private

#if swift(>=3.0)

extension Realm {
    /**
    A `Realm.Configuration` is used to describe the different options used to
    create a `Realm` instance.

    `Realm.Configuration` instances are just plain Swift structs, and unlike
    `Realm` and `Object`s can be freely shared between threads. Creating
    configuration objects for class subsets (by setting the `objectTypes`
    property) can be expensive, and so you will normally want to cache and reuse
    a single configuration object for each distinct configuration that you are
    using rather than creating a new one each time you open a `Realm`.
    */
    public struct Configuration {

        // MARK: Default Configuration

        /// Returns the default Realm.Configuration used to create Realms when no other
        /// configuration is explicitly specified (i.e. `Realm()`).
        public static var defaultConfiguration: Configuration {
            get {
                return fromRLMRealmConfiguration(rlmConfiguration: RLMRealmConfiguration.default())
            }
            set {
                RLMRealmConfiguration.setDefault(newValue.rlmConfiguration)
            }
        }

        // MARK: Initialization

        /**
        Initializes a `Realm.Configuration`, suitable for creating new `Realm` instances.

        - parameter fileURL:            The local URL to the realm file.
        - parameter inMemoryIdentifier: A string used to identify a particular in-memory Realm.
        - parameter encryptionKey:      64-byte key to use to encrypt the data.
        - parameter readOnly:           Whether the Realm is read-only (must be true for read-only files).
        - parameter schemaVersion:      The current schema version.
        - parameter migrationBlock:     The block which migrates the Realm to the current version.
        - parameter deleteRealmIfMigrationNeeded: If `true`, recreate the Realm file with the provided
                                                  schema if a migration is required.
        - parameter objectTypes:        The subset of `Object` subclasses persisted in the Realm.
        */
        public init(fileURL: URL? = URL(fileURLWithPath: RLMRealmPathForFile("default.realm"), isDirectory: false),
            inMemoryIdentifier: String? = nil,
            encryptionKey: Data? = nil,
            readOnly: Bool = false,
            schemaVersion: UInt64 = 0,
            migrationBlock: MigrationBlock? = nil,
            deleteRealmIfMigrationNeeded: Bool = false,
            objectTypes: [Object.Type]? = nil) {
                self.fileURL = fileURL
                if inMemoryIdentifier != nil {
                    self.inMemoryIdentifier = inMemoryIdentifier
                }
                self.encryptionKey = encryptionKey
                self.readOnly = readOnly
                self.schemaVersion = schemaVersion
                self.migrationBlock = migrationBlock
                self.deleteRealmIfMigrationNeeded = deleteRealmIfMigrationNeeded
                self.objectTypes = objectTypes
        }

        // MARK: Configuration Properties

        /// The local URL to the realm file.
        /// Mutually exclusive with `inMemoryIdentifier`.
        public var fileURL: URL? {
            set {
                _inMemoryIdentifier = nil
                _path = newValue?.path
            }
            get {
                return _path.map { URL(fileURLWithPath: $0) }
            }
        }

        private var _path: String?

        /// A string used to identify a particular in-memory Realm.
        /// Mutually exclusive with `path`.
        public var inMemoryIdentifier: String? {
            set {
                _path = nil
                _inMemoryIdentifier = newValue
            }
            get {
                return _inMemoryIdentifier
            }
        }

        private var _inMemoryIdentifier: String? = nil

        /// 64-byte key to use to encrypt the data.
        public var encryptionKey: Data? = nil

        /// Whether the Realm is read-only (must be true for read-only files).
        public var readOnly: Bool = false

        /// The current schema version.
        public var schemaVersion: UInt64 = 0

        /// The block which migrates the Realm to the current version.
        public var migrationBlock: MigrationBlock? = nil

        /**
        Recreate the Realm file with the provided schema if a migration is required.
        This is the case when the stored schema differs from the provided schema or
        the stored schema version differs from the version on this configuration.
        This deletes the file if a migration would otherwise be required or run.

        - note: This doesn't disable file format migrations.
        */
        public var deleteRealmIfMigrationNeeded: Bool = false

        /// The classes persisted in the Realm.
        public var objectTypes: [Object.Type]? {
            set {
                self.customSchema = newValue.map { RLMSchema(objectClasses: $0) }
            }
            get {
                return self.customSchema.map { $0.objectSchema.map { $0.objectClass as! Object.Type } }
            }
        }

        /// A custom schema to use for the Realm.
        private var customSchema: RLMSchema? = nil

        /// Allows to disable automatic format upgrades when accessing the Realm.
        internal var disableFormatUpgrade: Bool = false

        // MARK: Private Methods

        internal var rlmConfiguration: RLMRealmConfiguration {
            let configuration = RLMRealmConfiguration()
            if let fileURL = fileURL {
                configuration.fileURL = fileURL
            } else if let inMemoryIdentifier = inMemoryIdentifier {
                configuration.inMemoryIdentifier = inMemoryIdentifier
            } else {
                fatalError("A Realm Configuration must specify a path or an in-memory identifier.")
            }
            configuration.encryptionKey = self.encryptionKey
            configuration.readOnly = self.readOnly
            configuration.schemaVersion = self.schemaVersion
            configuration.migrationBlock = self.migrationBlock.map { accessorMigrationBlock($0) }
            configuration.deleteRealmIfMigrationNeeded = self.deleteRealmIfMigrationNeeded
            configuration.customSchema = self.customSchema
            configuration.disableFormatUpgrade = self.disableFormatUpgrade
            return configuration
        }

        internal static func fromRLMRealmConfiguration(rlmConfiguration: RLMRealmConfiguration) -> Configuration {
            var configuration = Configuration()
            configuration._path = rlmConfiguration.fileURL?.path
            configuration._inMemoryIdentifier = rlmConfiguration.inMemoryIdentifier
            configuration.encryptionKey = rlmConfiguration.encryptionKey
            configuration.readOnly = rlmConfiguration.readOnly
            configuration.schemaVersion = rlmConfiguration.schemaVersion
            configuration.migrationBlock = rlmConfiguration.migrationBlock.map { rlmMigration in
                return { migration, schemaVersion in
                    rlmMigration(migration.rlmMigration, schemaVersion)
                }
            }
            configuration.deleteRealmIfMigrationNeeded = rlmConfiguration.deleteRealmIfMigrationNeeded
            configuration.customSchema = rlmConfiguration.customSchema
            configuration.disableFormatUpgrade = rlmConfiguration.disableFormatUpgrade
            return configuration
        }
    }
}

// MARK: CustomStringConvertible

extension Realm.Configuration: CustomStringConvertible {
    /// Returns a human-readable description of the configuration.
    public var description: String {
        return gsub(pattern: "\\ARLMRealmConfiguration",
                    template: "Realm.Configuration",
                    string: rlmConfiguration.description) ?? ""
    }
}

#else

extension Realm {
    /**
     A `Configuration` instance describes the different options used to
     create an instance of a Realm.

     `Configuration` instances are just plain Swift structs. Unlike `Realm`s
     and `Object`s, they can be freely shared between threads as long as you do not
     mutate them.

     Creating configuration values for class subsets (by setting the
     `objectClasses` property) can be expensive. Because of this, you will normally want to
     cache and reuse a single configuration value for each distinct configuration rather than
     creating a new value each time you open a Realm.
     */
    public struct Configuration {

        // MARK: Default Configuration

        /// Returns the default configuration used to create Realms when no other
        /// configuration is explicitly specified (i.e. `Realm()`).
        public static var defaultConfiguration: Configuration {
            get {
                return fromRLMRealmConfiguration(RLMRealmConfiguration.default())
            }
            set {
                RLMRealmConfiguration.setDefault(newValue.rlmConfiguration)
            }
        }

        // MARK: Initialization

        /**
        Initializes a `Realm.Configuration`, suitable for creating new `Realm` instances.

        - parameter fileURL:            The local URL to the Realm file.
        - parameter inMemoryIdentifier: A string used to identify a particular in-memory Realm.
        - parameter encryptionKey:      An optional 64-byte key to use to encrypt the data.
        - parameter readOnly:           Whether the Realm is read-only (must be true for read-only files).
        - parameter schemaVersion:      The current schema version.
        - parameter migrationBlock:     The block which migrates the Realm to the current version.
        - parameter deleteRealmIfMigrationNeeded: If `true`, recreate the Realm file with the provided
                                                  schema if a migration is required.
        - parameter objectTypes:        The subset of `Object` subclasses managed by the Realm.
        */
        public init(fileURL: URL? = URL(fileURLWithPath: RLMRealmPathForFile("default.realm"), isDirectory: false),
            inMemoryIdentifier: String? = nil,
            encryptionKey: Data? = nil,
            readOnly: Bool = false,
            schemaVersion: UInt64 = 0,
            migrationBlock: MigrationBlock? = nil,
            deleteRealmIfMigrationNeeded: Bool = false,
            objectTypes: [Object.Type]? = nil) {
                self.fileURL = fileURL
                if inMemoryIdentifier != nil {
                    self.inMemoryIdentifier = inMemoryIdentifier
                }
                self.encryptionKey = encryptionKey
                self.readOnly = readOnly
                self.schemaVersion = schemaVersion
                self.migrationBlock = migrationBlock
                self.deleteRealmIfMigrationNeeded = deleteRealmIfMigrationNeeded
                self.objectTypes = objectTypes
        }

        // MARK: Configuration Properties

        /// The local URL of the Realm file. Mutually exclusive with `inMemoryIdentifier`.
        public var fileURL: URL? {
            set {
                _inMemoryIdentifier = nil
                _path = newValue?.path
            }
            get {
                return _path.map { URL(fileURLWithPath: $0) }
            }
        }

        fileprivate var _path: String?

        /// A string used to identify a particular in-memory Realm. Mutually exclusive with `fileURL`.
        public var inMemoryIdentifier: String? {
            set {
                _path = nil
                _inMemoryIdentifier = newValue
            }
            get {
                return _inMemoryIdentifier
            }
        }

        fileprivate var _inMemoryIdentifier: String? = nil

        /// A 64-byte key to use to encrypt the data, or `nil` if encryption is not enabled.
        public var encryptionKey: Data? = nil

        /// Whether to open the Realm in read-only mode.
        ///
        /// This is required to be able to open Realm files which are not
        /// writeable or are in a directory which is not writeable. This should
        /// only be used on files which will not be modified by anyone while
        /// they are open, and not just to get a read-only view of a file which
        /// may be written to by another thread or process. Opening in read-only
        /// mode requires disabling Realm's reader/writer coordination, so
        /// committing a write transaction from another process will result in
        /// crashes.
        public var readOnly: Bool = false

        /// The current schema version.
        public var schemaVersion: UInt64 = 0

        /// The block which migrates the Realm to the current version.
        public var migrationBlock: MigrationBlock? = nil

        /**
         Whether to recreate the Realm file with the provided schema if a migration is required.
         This is the case when the stored schema differs from the provided schema or
         the stored schema version differs from the version on this configuration.
         Setting this property to `true` deletes the file if a migration would otherwise be required or executed.

         - note: Setting this property to `true` doesn't disable file format migrations.
        */
        public var deleteRealmIfMigrationNeeded: Bool = false

        /// The classes managed by the Realm.
        public var objectTypes: [Object.Type]? {
            set {
                self.customSchema = newValue.map { RLMSchema(objectClasses: $0) }
            }
            get {
                return self.customSchema.map { $0.objectSchema.map { $0.objectClass as! Object.Type } }
            }
        }

        /// A custom schema to use for the Realm.
        fileprivate var customSchema: RLMSchema? = nil

        /// If `true`, disables automatic format upgrades when accessing the Realm.
        internal var disableFormatUpgrade: Bool = false

        // MARK: Private Methods

        internal var rlmConfiguration: RLMRealmConfiguration {
            let configuration = RLMRealmConfiguration()
            if fileURL != nil {
                configuration.fileURL = self.fileURL
            } else if inMemoryIdentifier != nil {
                configuration.inMemoryIdentifier = self.inMemoryIdentifier
            } else {
                fatalError("A Realm Configuration must specify a path or an in-memory identifier.")
            }
            configuration.encryptionKey = self.encryptionKey
            configuration.readOnly = self.readOnly
            configuration.schemaVersion = self.schemaVersion
            configuration.migrationBlock = self.migrationBlock.map { accessorMigrationBlock($0) }
            configuration.deleteRealmIfMigrationNeeded = self.deleteRealmIfMigrationNeeded
            configuration.customSchema = self.customSchema
            configuration.disableFormatUpgrade = self.disableFormatUpgrade
            return configuration
        }

        internal static func fromRLMRealmConfiguration(_ rlmConfiguration: RLMRealmConfiguration) -> Configuration {
            var configuration = Configuration()
            configuration._path = rlmConfiguration.fileURL?.path
            configuration._inMemoryIdentifier = rlmConfiguration.inMemoryIdentifier
            configuration.encryptionKey = rlmConfiguration.encryptionKey
            configuration.readOnly = rlmConfiguration.readOnly
            configuration.schemaVersion = rlmConfiguration.schemaVersion
            configuration.migrationBlock = rlmConfiguration.migrationBlock.map { rlmMigration in
                return { migration, schemaVersion in
                    rlmMigration(migration.rlmMigration, schemaVersion)
                }
            }
            configuration.deleteRealmIfMigrationNeeded = rlmConfiguration.deleteRealmIfMigrationNeeded
            configuration.customSchema = rlmConfiguration.customSchema
            configuration.disableFormatUpgrade = rlmConfiguration.disableFormatUpgrade
            return configuration
        }
    }
}

// MARK: CustomStringConvertible

extension Realm.Configuration: CustomStringConvertible {
    /// Returns a human-readable description of the configuration.
    public var description: String {
        return gsub("\\ARLMRealmConfiguration",
                    template: "Realm.Configuration",
                    string: rlmConfiguration.description) ?? ""
    }
}

#endif
