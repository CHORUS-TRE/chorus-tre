import os
import sys
from typing import Dict, List, Optional, Literal, Any
from http.cookiejar import DefaultCookiePolicy
import logging
from pathlib import Path
import requests
import yaml
from pydantic import BaseModel, Field, field_validator, ValidationError

logger = logging.getLogger(__name__)

DEFAULT_PAGE_SIZE = 100
DEFAULT_STORAGE_LIMIT = -1
DEFAULT_DURATION = -1
MANAGED_BY_MARKER = "[managed-by:harbor-config-job]"

class CredentialConfig(BaseModel):
    """Registry credential configuration"""
    type: str
    access_key: Optional[str] = None
    access_secret: Optional[str] = None

class RegistryConfig(BaseModel):
    """Registry configuration for proxy cache or replication"""
    name: str
    type: str
    url: str
    description: str = ""
    insecure: bool = False
    credential: Optional[CredentialConfig] = None

    @field_validator('url')
    @classmethod
    def validate_url(cls, v: str) -> str:
        if not v.startswith(('http://', 'https://')):
            raise ValueError('URL must start with http:// or https://')
        return v

    def get_request_data(self) -> Dict:
        """Generate request data for Harbor API with managed-by marker"""
        # Inject managed-by marker with stable ID into description
        managed_desc = f"{MANAGED_BY_MARKER} [id:{self.name}]"
        if self.description:
            managed_desc = f"{managed_desc} {self.description}"

        # Use model_dump and override description
        data = self.model_dump(exclude_none=True, exclude={'description'})
        data['description'] = managed_desc
        return data

class CVEAllowlistItem(BaseModel):
    """CVE allowlist item"""
    cve_id: str

class CVEAllowlist(BaseModel):
    """CVE allowlist configuration"""
    items: List[CVEAllowlistItem] = Field(default_factory=list)
    expires_at: Optional[int] = None

class TagSelector(BaseModel):
    """Tag selector for retention rules"""
    kind: str
    decoration: str
    pattern: str
    extras: Optional[str] = None

class ScopeSelector(BaseModel):
    """Scope selector for retention rules"""
    kind: str
    decoration: str
    pattern: str
    extras: Optional[str] = None

class RetentionRule(BaseModel):
    """Individual retention rule"""
    priority: int
    disabled: bool = False
    action: str
    template: str
    params: Dict[str, Any] = Field(default_factory=dict)
    tag_selectors: List[TagSelector]
    scope_selectors: Dict[str, List[ScopeSelector]] = Field(default_factory=dict)

class RetentionTrigger(BaseModel):
    """Retention policy trigger"""
    kind: str
    settings: Dict[str, Any] = Field(default_factory=dict)
    references: Dict[str, Any] = Field(default_factory=dict)

class RetentionScope(BaseModel):
    """Retention policy scope"""
    level: str = "project"
    ref: int

class RetentionPolicy(BaseModel):
    """Harbor retention policy"""
    algorithm: str = "or"
    rules: List[RetentionRule]
    trigger: RetentionTrigger
    scope: Optional[RetentionScope] = None

    def get_request_data(self) -> Dict:
        """Generate request data for Harbor API"""
        return {
            "algorithm": self.algorithm,
            "rules": [
                {
                    "priority": rule.priority,
                    "disabled": rule.disabled,
                    "action": rule.action,
                    "template": rule.template,
                    "params": rule.params,
                    "tag_selectors": [ts.model_dump() for ts in rule.tag_selectors],
                    "scope_selectors": {
                        key: [selector.model_dump() for selector in selectors]
                        for key, selectors in rule.scope_selectors.items()
                    }
                }
                for rule in self.rules
            ],
            "trigger": self.trigger.model_dump(),
            "scope": self.scope.model_dump()
        }

class ProjectConfig(BaseModel):
    """Harbor project configuration"""
    project_name: str
    public: bool = False

    # Metadata fields
    auto_scan: bool = True
    severity: Literal['low', 'medium', 'high', 'critical'] = 'low'
    enable_content_trust: bool = False
    enable_content_trust_cosign: bool = False
    prevent_vul: bool = False
    auto_sbom_generation: bool = False
    reuse_sys_cve_allowlist: bool = True
    proxy_speed_kb: int = -1

    # Top-level fields
    storage_limit: int = Field(default=-1, ge=-1)
    registry_id: Optional[int] = None
    cve_allowlist: Optional[CVEAllowlist] = None

    # Config-only fields
    registry: Optional[RegistryConfig] = Field(default=None, exclude=True)
    retention_policy: Optional[RetentionPolicy] = Field(default=None, exclude=True)

    @field_validator('project_name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError('Project name cannot be empty')
        return v

    def get_metadata(self) -> Dict[str, str]:
        """Generate Harbor metadata dict with boolean to string conversion"""
        metadata = {
            "public": str(self.public).lower(),
            "auto_scan": str(self.auto_scan).lower(),
            "severity": self.severity,
            "enable_content_trust": str(self.enable_content_trust).lower(),
            "enable_content_trust_cosign": str(self.enable_content_trust_cosign).lower(),
            "prevent_vul": str(self.prevent_vul).lower(),
            "auto_sbom_generation": str(self.auto_sbom_generation).lower(),
            "reuse_sys_cve_allowlist": str(self.reuse_sys_cve_allowlist).lower(),
        }

        if self.proxy_speed_kb >= 0:
            metadata['proxy_speed_kb'] = str(self.proxy_speed_kb)

        return metadata

    def get_request_data(self, registry_id: Optional[int] = None) -> Dict:
        """Generate request data for Harbor API"""
        data = {
            'project_name': self.project_name,
            "public": self.public,
            "metadata": self.get_metadata(),
            "storage_limit": self.storage_limit
        }

        if registry_id:
            data['registry_id'] = registry_id

        if self.cve_allowlist and not self.reuse_sys_cve_allowlist:
            data['cve_allowlist'] = self.cve_allowlist.model_dump(exclude_none=True)

        return data

class PermissionAccess(BaseModel):
    """Individual permission access rule"""
    resource: str
    action: str
    effect: Literal['allow', 'deny'] = 'allow'

    @field_validator('resource', 'action')
    @classmethod
    def validate_not_empty(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError('Resource and action cannot be empty')
        return v

class Permission(BaseModel):
    """Robot account permission"""
    kind: Literal['system', 'project']
    namespace: str
    access: List[PermissionAccess]

    @field_validator('access')
    @classmethod
    def validate_access_not_empty(cls, v: List[PermissionAccess]) -> List[PermissionAccess]:
        if not v:
            raise ValueError('Access list cannot be empty')
        return v

class RobotConfig(BaseModel):
    """Robot account configuration (system-level only)"""
    name: str
    description: str = ""
    duration: int = Field(default=-1, ge=-1)
    disable: bool = False
    permissions: List[Permission]

    @field_validator('name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError('Robot name cannot be empty')
        if v.startswith('robot$'):
            raise ValueError('Robot name should not include robot$ prefix')
        return v

    @field_validator('permissions')
    @classmethod
    def validate_permissions_not_empty(cls, v: List[Permission]) -> List[Permission]:
        if not v:
            raise ValueError('Permissions list cannot be empty')
        return v

    def get_create_data(self, secret: str) -> Dict:
        """Generate creation data for Harbor API"""
        # Inject managed-by marker into description
        managed_desc = f"{MANAGED_BY_MARKER}"
        if self.description:
            managed_desc = f"{managed_desc} {self.description}"

        data = {
            "name": self.name,
            "description": managed_desc,
            "duration": self.duration,
            "level": "system",
            "disable": self.disable,
            "permissions": [p.model_dump() for p in self.permissions],
            "secret": secret
        }

        return data

    def get_update_data(self, secret: str) -> Dict:
        """Generate update data for Harbor API"""
        data = self.get_create_data(secret)
        data["name"] = f"robot${self.name}"
        return data

class FilterConfig(BaseModel):
    """Replication filter configuration"""
    type: Literal['name', 'tag', 'resource', 'label'] = 'name'
    value: str = '**'

    def get_request_data(self) -> Dict:
        """Generate request data for Harbor API"""
        return {
            "type": self.type,
            "value": self.value
        }

class TriggerConfig(BaseModel):
    """Replication trigger configuration"""
    mode: Literal['manual', 'scheduled', 'event_based'] = 'manual'
    cron: str = ""

    @field_validator('cron')
    @classmethod
    def validate_cron(cls, v: str, info) -> str:
        # If mode is scheduled, cron expression is required
        if info.data.get('mode') == 'scheduled' and not v:
            raise ValueError('Cron expression is required for scheduled triggers')
        return v

    def get_request_data(self) -> Dict:
        """Generate request data for Harbor API"""
        data = {"type": self.mode}
        if self.mode == "scheduled":
            data["trigger_settings"] = {"cron": self.cron}
        return data

class ReplicationConfig(BaseModel):
    """Replication policy configuration"""
    name: str
    mode: Literal['pull', 'push']
    description: str = ""
    registry: RegistryConfig
    dest_namespace: str = ""
    filters: List[FilterConfig] = Field(default_factory=list)
    flattening: int = Field(default=1, ge=0, le=3)
    trigger: TriggerConfig = TriggerConfig()
    replicate_deletion: bool = False
    bandwidth: int = Field(default=-1, ge=-1)
    override: bool = True
    enabled: bool = True
    copyByChunk: bool = False

    @field_validator('name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError('Replication name cannot be empty')
        return v

    def get_request_data(self, registry_id: int, insecure: bool = False) -> Dict:
        """Generate request data for Harbor API with managed-by marker"""
        # Build filters
        filters = [f.get_request_data() for f in self.filters]

        # Inject managed-by marker with stable ID into description
        managed_desc = f"{MANAGED_BY_MARKER} [id:{self.name}]"
        if self.description:
            managed_desc = f"{managed_desc} {self.description}"

        data = {
            "name": self.name,
            "description": managed_desc,
            "dest_namespace": self.dest_namespace,
            "filters": filters if filters else None,
            "dest_namespace_replace_count": self.flattening,
            "trigger": self.trigger.get_request_data(),
            "replicate_deletion": self.replicate_deletion,
            "override": self.override,
            "enabled": self.enabled,
            "speed": self.bandwidth,
            "copy_by_chunk": self.copyByChunk
        }

        registry_data = {
            "id": registry_id,
            "insecure": insecure
        }

        if self.mode == 'pull':
            data["src_registry"] = registry_data
        else:
            data["dest_registry"] = registry_data

        return data

class HarborConfigurator:
    """
    Harbor API client for managing registries, projects, and robot accounts.

    This class provides methods to interact with Harbor's REST API for creating
    and updating configuration resources. It handles authentication, SSL verification,
    and provides high-level operations for Harbor resource management.

    Attributes:
        url (str): Base URL of the Harbor instance
        session (requests.Session): HTTP session with authentication configured
    """
    def __init__(self, url: str, username: str, password: str):
        self.url = url.rstrip('/')
        self.session = requests.Session()
        self.session.auth = (username, password)
        verify_ssl = os.getenv('HARBOR_VERIFY_SSL', 'true').lower()
        self.session.verify = verify_ssl in ('true', '1', 'yes')
        # Disable cookie policy to avoid issues with CSRF tokens
        self.session.cookies.set_policy(DefaultCookiePolicy(allowed_domains=[]))

        logger.info("Harbor client initialized")

    @staticmethod
    def parse_stable_id(description: str, fallback: str = None) -> Optional[str]:
        """Extract stable ID from description field.

        Format: "[managed-by:harbor-config-job] [id:stable-id] user description"

        Args:
            description: Description field from Harbor resource
            fallback: Fallback value if parsing fails

        Returns:
            Stable ID string or fallback value
        """
        if 'id:' in description:
            try:
                id_part = description.split('id:')[1].split(']')[0].strip()
                if id_part:
                    return id_part
            except (IndexError, ValueError):
                logger.warning("Could not parse stable ID from description: %s", description)
        return fallback

    def get_registries(self) -> Dict[str, tuple]:
        """Get managed registries as dict mapping stable_id to (registry_id, current_name)"""
        try:
            response = self.session.get(f"{self.url}/api/v2.0/registries")
            response.raise_for_status()
            registries = response.json()

            managed = {}
            for r in registries:
                desc = r.get('description', '')
                # Check if this registry is managed by us
                if MANAGED_BY_MARKER in desc:
                    # Extract stable ID from description, or use registry name as fallback
                    stable_id = self.parse_stable_id(desc, fallback=r['name'])
                    managed[stable_id] = (r['id'], r['name'])

            return managed
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting registries: %s", e)
            raise

    def get_project_registry_id(self, project_name: str, registries: Dict[str, tuple]) -> Optional[tuple]:
        """Get registry stable_id and registry_id associated with a proxy cache project
        Returns (stable_id, registry_id, current_name) tuple or None
        """
        try:
            response = self.session.get(f"{self.url}/api/v2.0/projects/{project_name}")
            response.raise_for_status()
            project = response.json()
            registry_id = project.get('registry_id', None)

            if not registry_id:
                return None

            # Find the stable_id for this registry_id
            for stable_id, (reg_id, reg_name) in registries.items():
                if reg_id == registry_id:
                    return (stable_id, reg_id, reg_name)

            return None
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting project '%s': %s", project_name, e)
            raise

    def get_replication_registry_id(self, replication_id: int, replication_mode: str) -> Optional[int]:
        """Get registry ID associated with a replication policy"""
        replication_name = str(replication_id)
        try:
            response = self.session.get(f"{self.url}/api/v2.0/replication/policies/{replication_id}")
            response.raise_for_status()
            replication = response.json()
            replication_name = replication.get('name', '')
            if replication_mode == 'pull':
                return replication['src_registry'].get('id', None)
            return replication['dest_registry'].get('id', None)
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting registry ID for replication policy '%s': %s", replication_name, e)
            raise

    def create_registry(self, registry: RegistryConfig) -> int:
        """Create new registry, returns registry ID"""
        registry_name = registry.name
        data = registry.get_request_data()

        try:
            response = self.session.post(
                f"{self.url}/api/v2.0/registries",
                json=data
            )
            response.raise_for_status()

            # Harbor returns 201 with Location header, no response body
            registry_id = None
            location = response.headers.get('Location')
            if location:
                # Extract ID from Location header like "/api/v2.0/registries/1"
                try:
                    registry_id = int(location.rstrip('/').split('/')[-1])
                except (ValueError, IndexError):
                    logger.warning("Could not parse registry ID from Location: %s", location)

            # Fallback: fetch registry list to get ID
            if not registry_id:
                updated_registries = self.get_registries()
                registry_id = updated_registries.get(registry_name)

            if not registry_id:
                logger.error("Could not determine ID of created registry '%s'", registry_name)
                raise RuntimeError("Registry ID not found after creation")

            logger.info("Created registry '%s' (ID: %s)", registry_name, registry_id)
            return registry_id
        except requests.exceptions.RequestException as e:
            logger.error("Failed creating registry '%s': %s", registry_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def update_registry(self, registry_id: int, registry: RegistryConfig) -> bool:
        """Update existing registry, returns bool success"""
        registry_name = registry.name
        data = registry.get_request_data()

        try:
            response = self.session.put(
                f"{self.url}/api/v2.0/registries/{registry_id}",
                json=data
            )
            response.raise_for_status()
            logger.info("Updated registry '%s' (ID: %s)", registry_name, registry_id)
            return True
        except requests.exceptions.RequestException as e:
            logger.error("Failed updating registry '%s': %s", registry_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def get_projects(self) -> List[str]:
        """Get existing project names"""
        try:
            response = self.session.get(f"{self.url}/api/v2.0/projects")
            response.raise_for_status()
            return [p['name'] for p in response.json()]
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting projects: %s", e)
            raise

    def get_project_id(self, project_name: str) -> Optional[int]:
        """Get project ID by name"""
        try:
            response = self.session.get(f"{self.url}/api/v2.0/projects/{project_name}")
            response.raise_for_status()
            project = response.json()
            return project.get('project_id')
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting project ID for '%s': %s", project_name, e)
            return None

    def create_project(self, project: ProjectConfig, registry_id: int = None) -> bool:
        """Create new project"""
        data = project.get_request_data(registry_id)

        try:
            response = self.session.post(
                f"{self.url}/api/v2.0/projects",
                json=data
            )
            response.raise_for_status()
            logger.info("Created project '%s'%s", project.project_name, f" (proxy cache for registry ID {registry_id})" if registry_id else "")
            return True
        except requests.exceptions.RequestException as e:
            logger.error("Failed creating project '%s': %s", project.project_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def update_project(self, project: ProjectConfig) -> bool:
        """Update existing project"""
        # Note: registry_id is immutable after creation, so not included here
        data = project.get_request_data()

        try:
            response = self.session.put(
                f"{self.url}/api/v2.0/projects/{project.project_name}",
                json=data
            )
            response.raise_for_status()

            # Get project ID for logging
            project_id = self.get_project_id(project.project_name)
            logger.info("Updated project '%s' (ID: %s)", project.project_name, project_id)
            return True
        except requests.exceptions.RequestException as e:
            logger.error("Failed updating project '%s': %s", project.project_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def get_system_robots(self) -> Dict[str, int]:
        """Get managed system-level robot accounts as dict mapping name to ID"""
        try:
            managed = {}
            page = 1
            page_size = DEFAULT_PAGE_SIZE

            while True:
                response = self.session.get(
                    f"{self.url}/api/v2.0/robots",
                    params={"page": page, "page_size": page_size}
                )
                response.raise_for_status()
                robots = response.json()

                if not robots:
                    break

                for r in robots:
                    desc = r.get('description', '')
                    # Check if this robot is managed by us
                    if MANAGED_BY_MARKER in desc:
                        managed[r.get('name', '')] = r.get('id')
                page += 1

            return managed
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting system robots: %s", e)
            raise

    def get_robot_secret(self, robot_name: str, secret_dir: Path) -> str:
        """Load predefined secret from file named after robot """

        secret_file = secret_dir / robot_name
        if not secret_file.exists():
            logger.error("Secret file not found for robot '%s': %s", robot_name, secret_file)
            raise FileNotFoundError(f"Required secret file not found: {secret_file}")

        try:
            robot_secret = secret_file.read_text().strip()
            if not robot_secret:
                logger.error("Secret file is empty for robot '%s': %s", robot_name, secret_file)
                raise ValueError(f"Secret file is empty: {secret_file}")
            logger.info("Loaded secret for robot '%s' from %s", robot_name, secret_file)
            return robot_secret
        except (FileNotFoundError, ValueError):
            raise
        except Exception as e:
            logger.error("Failed reading secret file %s: %s", secret_file, e)
            raise

    def update_robot(self, robot_id: int, robot: RobotConfig, secret_dir: Path) -> bool:
        """Update existing robot account"""
        robot_name = robot.name
        robot_secret = self.get_robot_secret(robot_name, secret_dir)
        data = robot.get_update_data(secret=robot_secret)

        try:
            response = self.session.put(
                f"{self.url}/api/v2.0/robots/{robot_id}",
                json=data
            )
            response.raise_for_status()
            logger.info("Updated robot '%s' (ID: %s)", robot_name, robot_id)
            return True
        except requests.exceptions.RequestException as e:
            logger.error("Failed updating robot '%s': %s", robot_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def create_robot(self, robot: RobotConfig, secret_dir: Path) -> Optional[Dict[str, str]]:
        """Create new system-level robot account"""
        robot_name = robot.name
        robot_secret = self.get_robot_secret(robot_name, secret_dir)
        data = robot.get_create_data(secret=robot_secret)

        try:
            response = self.session.post(
                f"{self.url}/api/v2.0/robots",
                json=data
            )
            response.raise_for_status()
            result = response.json()

            logger.info("Created robot '%s'", robot_name)

            return {
                'name': result['name'],
                'secret': result['secret'],
                'token': result.get('token', '')
            }
        except requests.exceptions.RequestException as e:
            logger.error("Failed creating robot '%s': %s", robot_name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def get_replications(self) -> Dict[str, tuple]:
        """Get managed replication policies as dict mapping stable_id to (policy_id, current_name)"""
        try:
            response = self.session.get(f"{self.url}/api/v2.0/replication/policies")
            response.raise_for_status()
            replications = response.json()

            managed = {}
            for r in replications:
                desc = r.get('description', '')
                # Check if this policy is managed by us
                if MANAGED_BY_MARKER in desc:
                    # Extract stable ID from description
                    stable_id = self.parse_stable_id(desc)
                    if stable_id:
                        managed[stable_id] = (r['id'], r['name'])

            return managed
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting replication policies: %s", e)
            raise

    def create_replication(self, replication: ReplicationConfig, registry_id: int = None) -> bool:
        """Create new replication policy"""
        data = replication.get_request_data(registry_id=registry_id, insecure=replication.registry.insecure)

        try:
            response = self.session.post(
                f"{self.url}/api/v2.0/replication/policies",
                json=data
            )
            response.raise_for_status()
            logger.info("Created replication policy '%s' (%s-based replication for registry ID %s)", replication.name, replication.mode, registry_id)
            return True
        except requests.exceptions.RequestException as e:
            logger.error("Failed creating replication policy '%s': %s", replication.name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def update_replication(self, replication_id: int, registry_id: int, replication: ReplicationConfig) -> bool:
        """Update existing replication policy"""
        data = replication.get_request_data(registry_id=registry_id, insecure=replication.registry.insecure)

        try:
            response = self.session.put(
                f"{self.url}/api/v2.0/replication/policies/{replication_id}",
                json=data
            )
            response.raise_for_status()
            logger.info("Updated replication policy '%s' (ID: %s)", replication.name, replication_id)
            return True
        except requests.exceptions.RequestException as e:
            logger.error("Failed updating replication policy '%s': %s", replication.name, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def get_retention_policy(self, project_name: str) -> Optional[int]:
        """Get retention policy ID for a project"""
        try:
            response = self.session.get(f"{self.url}/api/v2.0/projects/{project_name}")
            response.raise_for_status()
            project_data = response.json()

            # Extract retention_id from metadata
            retention_id_str = project_data.get('metadata', {}).get('retention_id')
            if retention_id_str:
                return int(retention_id_str)

            return None
        except requests.exceptions.RequestException as e:
            logger.error("Failed getting retention policy for project '%s': %s", project_name, e)
            return None

    def create_retention_policy(self, policy: RetentionPolicy) -> Optional[int]:
        """Create retention policy, returns policy ID"""
        data = policy.get_request_data()

        try:
            response = self.session.post(
                f"{self.url}/api/v2.0/retentions",
                json=data
            )
            response.raise_for_status()

            # Harbor returns 201 with Location header
            policy_id = None
            location = response.headers.get('Location')
            if location:
                try:
                    policy_id = int(location.rstrip('/').split('/')[-1])
                except (ValueError, IndexError):
                    logger.warning("Could not parse retention policy ID from Location: %s", location)

            if policy_id:
                logger.info("Created retention policy (ID: %s) for project ID %s", policy_id, policy.scope.ref)
            return policy_id
        except requests.exceptions.RequestException as e:
            logger.error("Failed creating retention policy: %s", e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

    def update_retention_policy(self, policy_id: int, policy: RetentionPolicy) -> bool:
        """Update existing retention policy"""
        data = policy.get_request_data()

        try:
            response = self.session.put(
                f"{self.url}/api/v2.0/retentions/{policy_id}",
                json=data
            )
            response.raise_for_status()
            logger.info("Updated retention policy (ID: %s) for project ID %s", policy_id, policy.scope.ref)
            return True
        except requests.exceptions.RequestException as e:
            logger.error("Failed updating retention policy ID %s: %s", policy_id, e)
            if hasattr(e, 'response') and hasattr(e.response, 'text'):
                logger.error("  Response: %s", e.response.text)
            raise

def main() -> None:
    """
    Configure Harbor by creating projects and robot accounts from YAML config files.

    Requires environment variables:
    - HARBOR_URL: Harbor instance URL
    - HARBOR_ADMIN_PASSWORD: Admin password
    - HARBOR_ADMIN_USER: Admin username (default: 'admin')
    - HARBOR_VERIFY_SSL: SSL verification (default: 'true')
    - LOG_LEVEL: Logging level (default: 'INFO', options: DEBUG, INFO, WARNING, ERROR, CRITICAL)
    - CONFIG_DIR: Directory containing config files (default: '/config')
    - SECRET_DIR: Directory containing robot secret files (default: '/secrets')
    """
    # Configure logging
    log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
    logging.basicConfig(
        level=getattr(logging, log_level, logging.INFO),
        format='%(message)s'
    )

    harbor_url = os.getenv('HARBOR_URL')
    admin_user = os.getenv('HARBOR_ADMIN_USER', 'admin')
    admin_pass = os.getenv('HARBOR_ADMIN_PASSWORD')
    config_dir = Path(os.getenv('CONFIG_DIR', '/config'))
    secret_dir = Path(os.getenv('SECRET_DIR', '/secrets'))

    if not harbor_url or not admin_pass:
        logger.error("HARBOR_URL and HARBOR_ADMIN_PASSWORD must be set")
        sys.exit(1)

    logger.info("🌊 Configuring Harbor at %s", harbor_url)
    logger.info("Admin user: %s", admin_user)
    logger.info("Config dir: %s", config_dir)
    try:
        harbor = HarborConfigurator(harbor_url, admin_user, admin_pass)
    except Exception as e:
        logger.error("Failed to initialize Harbor client: %s", e)
        sys.exit(1)

    # Load and apply projects
    projects_created = 0
    projects_updated = 0
    registries_created = 0
    registries_updated = 0
    try:
        with open(config_dir / 'projects.yaml', encoding='utf-8') as f:
            projects_data = yaml.safe_load(f) or []
            logger.info("\n📦 Processing projects...")

            # Validate and parse projects
            projects = []
            for idx, project_data in enumerate(projects_data):
                try:
                    projects.append(ProjectConfig(**project_data))
                except ValidationError as e:
                    logger.error("Invalid project configuration at index %d: %s", idx, e)
                    sys.exit(1)

            existing_registries = harbor.get_registries()
            existing_projects = harbor.get_projects()
            for project in projects:
                project_name = project.project_name
                registry_id = None
                registry = project.registry
                registry_stable_id = registry.name if registry else None

                if project_name in existing_projects:
                    if registry:
                        # Check if project has an associated registry
                        registry_info = harbor.get_project_registry_id(project_name, existing_registries)
                        if registry_info:
                            stable_id, reg_id, current_name = registry_info
                            if current_name != registry.name:
                                logger.info("Registry name changed in Harbor from '%s' to '%s', reverting to config", current_name, registry.name)
                            if harbor.update_registry(reg_id, registry):
                                registries_updated += 1
                            registry_id = reg_id
                        else:
                            # Project exists but its registry is not managed by this script
                            logger.warning("Ignoring registry configurations for project '%s' because its registry is not managed by this script (missing '%s' marker in registry description)", project_name, MANAGED_BY_MARKER)
                    if harbor.update_project(project):
                        projects_updated += 1
                else:
                    if registry and registry_stable_id in existing_registries:
                        # Registry already exists, reuse it
                        reg_id, current_name = existing_registries[registry_stable_id]
                        if current_name != registry.name:
                            logger.info("Registry name changed in Harbor from '%s' to '%s', reverting to config", current_name, registry.name)
                            if harbor.update_registry(reg_id, registry):
                                registries_updated += 1
                        registry_id = reg_id
                    elif registry:
                        # Create new registry
                        registry_id = harbor.create_registry(registry)
                        if registry_id:
                            registries_created += 1
                    if harbor.create_project(project, registry_id):
                        projects_created += 1

            # Process retention policies after projects are created
            retentions_created = 0
            retentions_updated = 0
            for project in projects:
                if project.retention_policy:
                    project_id = harbor.get_project_id(project.project_name)
                    if not project_id:
                        logger.error("Cannot create retention policy for project '%s' because project ID not found", project.project_name)
                        continue

                    # Set the retention policy scope with actual project_id
                    project.retention_policy.scope = RetentionScope(level="project", ref=project_id)

                    # Check if retention policy already exists
                    existing_policy_id = harbor.get_retention_policy(project.project_name)
                    if existing_policy_id:
                        if harbor.update_retention_policy(existing_policy_id, project.retention_policy):
                            retentions_updated += 1
                    else:
                        if harbor.create_retention_policy(project.retention_policy):
                            retentions_created += 1
    except FileNotFoundError:
        logger.warning("⚠️  No projects.yaml found, skipping projects")
    except Exception as e:
        logger.error("Failed processing projects: %s", e)
        sys.exit(1)

    # Load and apply robots
    robots_created = 0
    robots_updated = 0
    try:
        with open(config_dir / 'robots.yaml', encoding='utf-8') as f:
            robots_data = yaml.safe_load(f) or []
            logger.info("\n🤖 Processing robot accounts...")

            # Validate and parse robots
            robots = []
            for idx, robot_data in enumerate(robots_data):
                try:
                    robots.append(RobotConfig(**robot_data))
                except ValidationError as e:
                    logger.error("Invalid robot configuration at index %d: %s", idx, e)
                    sys.exit(1)

            existing_robots = harbor.get_system_robots()
            for robot in robots:
                robot_name = "robot$" + robot.name
                if robot_name in existing_robots:
                    robot_id = existing_robots[robot_name]
                    harbor.update_robot(robot_id, robot, secret_dir)
                    robots_updated += 1
                else:
                    if harbor.create_robot(robot, secret_dir):
                        robots_created += 1
    except FileNotFoundError:
        logger.warning("⚠️  No robots.yaml found, skipping robots")
    except Exception as e:
        logger.error("Failed processing robots: %s", e)
        sys.exit(1)

    # Load and apply replication policies
    replications_created = 0
    replications_updated = 0
    try:
        with open(config_dir / 'replications.yaml', encoding='utf-8') as f:
            replications_data = yaml.safe_load(f) or []
            logger.info("\n🔁 Processing replication policies...")

            # Validate and parse replications
            replications = []
            for idx, replication_data in enumerate(replications_data):
                try:
                    replications.append(ReplicationConfig(**replication_data))
                except ValidationError as e:
                    logger.error("Invalid replication configuration at index %d: %s", idx, e)
                    sys.exit(1)

            existing_registries = harbor.get_registries()
            existing_replications = harbor.get_replications()
            for replication in replications:
                replication_name = replication.name
                stable_id = replication_name  # Use name as stable ID
                registry = replication.registry
                registry_stable_id = registry.name
                registry_id = None
                replication_mode = replication.mode

                if stable_id in existing_replications:
                    replication_id, current_name = existing_replications[stable_id]
                    if current_name != replication_name:
                        logger.info("Replication policy name changed in Harbor from '%s' to '%s', reverting to config", current_name, replication_name)

                    # Get the registry ID from the replication policy
                    registry_id = harbor.get_replication_registry_id(replication_id, replication_mode)
                    if registry_id:
                        # Find the stable_id for this registry
                        found = False
                        for reg_stable_id, (reg_id, reg_name) in existing_registries.items():
                            if reg_id == registry_id:
                                if reg_name != registry.name:
                                    logger.info("Registry name changed in Harbor from '%s' to '%s', reverting to config", reg_name, registry.name)
                                if harbor.update_registry(registry_id, registry):
                                    registries_updated += 1
                                found = True
                                break
                        if not found:
                            logger.warning("Registry ID %s for replication '%s' is not managed by this script. To manage this registry, ensure its description contains '%s'", registry_id, replication_name, MANAGED_BY_MARKER)
                    else:
                        logger.error("Cannot update registry for replication '%s' because it does not exist", replication_name)
                        raise RuntimeError(f"Registry does not exist for replication: {replication_name}")
                    if harbor.update_replication(replication_id, registry_id, replication):
                        replications_updated += 1
                else:
                    # Check if registry already exists
                    if registry_stable_id in existing_registries:
                        reg_id, reg_name = existing_registries[registry_stable_id]
                        if reg_name != registry.name:
                            logger.info("Registry name changed in Harbor from '%s' to '%s', reverting to config", reg_name, registry.name)
                            if harbor.update_registry(reg_id, registry):
                                registries_updated += 1
                        registry_id = reg_id
                    else:
                        # Create new registry
                        registry_id = harbor.create_registry(registry)
                        if registry_id:
                            registries_created += 1
                    if harbor.create_replication(replication, registry_id):
                        replications_created += 1
    except FileNotFoundError:
        logger.warning("⚠️  No replications.yaml found, skipping replications")
    except Exception as e:
        logger.error("Failed processing replications: %s", e)
        sys.exit(1)

    # Summary
    logger.info("\n✅ Harbor configuration complete!")
    if projects_created > 0:
        logger.info("Projects created: %s", projects_created)
    if projects_updated > 0:
        logger.info("Projects updated: %s", projects_updated)
    if retentions_created > 0:
        logger.info("Retention policies created: %s", retentions_created)
    if retentions_updated > 0:
        logger.info("Retention policies updated: %s", retentions_updated)
    if replications_created > 0:
        logger.info("Replications created: %s", replications_created)
    if replications_updated > 0:
        logger.info("Replications updated: %s", replications_updated)
    if registries_created > 0:
        logger.info("Registries created: %s", registries_created)
    if registries_updated > 0:
        logger.info("Registries updated: %s", registries_updated)
    if robots_created > 0:
        logger.info("Robots created: %s", robots_created)
    if robots_updated > 0:
        logger.info("Robots updated: %s", robots_updated)

if __name__ == '__main__':
    main()
