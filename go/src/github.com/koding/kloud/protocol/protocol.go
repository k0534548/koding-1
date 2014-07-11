package protocol

import (
	"github.com/koding/kloud/eventer"
	"github.com/koding/kloud/machinestate"
)

// Builder creates and provision a single image or machine for a given Provider.
type Builder interface {
	Build(*MachineOptions) (*ProviderArtifact, error)
}

// Provider manages a machine, it's start/stop/destroy/restart a machine.
type Controller interface {
	// Start starts the machine
	Start(*MachineOptions) (*ProviderArtifact, error)

	// Stop stops the machine
	Stop(*MachineOptions) error

	// Restart restarts the machine
	Restart(*MachineOptions) error

	// Destroy destroys the machine
	Destroy(*MachineOptions) error

	// Info returns full information about a single machine
	Info(*MachineOptions) (*InfoArtifact, error)
}

// contains all necessary informations.
type MachineOptions struct {
	// MachineId defines a unique ID in which the build informations are
	// fetched from. MachineId is used to gather the Username, ImageName,
	// InstanceName etc.. For example it could be a mongodb object id that
	// would point to a document that carries those informations or a key for a
	// key/value storage.
	MachineId string

	// Username defines the username on behalf the machine is being build.
	Username string

	// ImageName is used to build the machine based on this particular image.
	ImageName string

	// InstanceName is used to change the machine name (usually hostname). If
	// it's empty a unique name will be used.
	InstanceName string

	// Builder contains information about how to build the data
	Builder map[string]interface{}

	// Credential contains information for accessing third party provider services
	Credential map[string]interface{}

	// Deploy is used for custom provisioning and creating a machine
	Deploy *ProviderDeploy

	// Eventer pushes the latest events to the build event.
	Eventer eventer.Eventer
}

// If available a key pair with the given public key and name should be
// deployed to the machine, the corresponding PrivateKey should be returned
// in the ProviderArtifact. Some providers such as Amazon creates
// publicKey's on the fly and generates the privateKey themself. The
// Deployer interface is then executed (only if the necessary privateKey is
// passed)
type ProviderDeploy struct {
	PublicKey  string
	PrivateKey string
	KeyName    string
	Username   string
}

// ProviderArtifact should be returned from a Build method.
type ProviderArtifact struct {
	// InstanceName should define the name/hostname of the created machine. It
	// should be equal to the InstanceName that was passed via MachineOptions.
	InstanceName string

	// InstanceId should define a unique ID that defined the created machine.
	// It's different than the machineID and is usually an unique id which is
	// given by the third-party provider, for example DigitalOcean returns a
	// droplet Id.
	InstanceId string

	// IpAddress defines the public ip address of the running machine.
	IpAddress string

	// PrivateKey defines a private SSH key added to the machine. It's only
	// returned if the SSHKeyName and SSHPublicKey is defined in MachineOptions
	SSHPrivateKey string
	SSHUsername   string
}

// InfoArtifact should be returned from a Info method.
type InfoArtifact struct {
	// State defines the state of the machine
	State machinestate.State

	// Name defines the name of the machine.
	Name string
}

// Deployer deploys a machine after it's being built.
type Deployer interface {
	// Deploy can only be executed after a build. The machine needs to be
	// publicly available.
	Deploy(*DeployOptions) (*DeployArtifact, error)
}

// DeployOptions is passed to a Deploy method
type DeployOptions struct {
	// Artifact comes from a Build process
	Artifact *ProviderArtifact

	// Username defines the username to which the machine belongs.
	Username string
}

// DeployArtifact should be returned from a Deploy Method
type DeployArtifact struct {
	KiteQuery string
}
