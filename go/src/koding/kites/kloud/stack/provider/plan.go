package provider

import (
	"koding/db/models"
	"koding/kites/kloud/stack"
	"koding/kites/kloud/terraformer"
	tf "koding/kites/terraformer"
	"koding/tools/util"

	"golang.org/x/net/context"
)

var escapeVars = []string{
	"userInput_",
	"payload_",
}

func (bs *BaseStack) HandlePlan(ctx context.Context) (interface{}, error) {
	arg, ok := ctx.Value(stack.PlanRequestKey).(*stack.PlanRequest)
	if !ok {
		arg = &stack.PlanRequest{}

		if err := bs.Req.Args.One().Unmarshal(arg); err != nil {
			return nil, err
		}
	}

	if err := arg.Valid(); err != nil {
		return nil, err
	}

	bs.Arg = arg

	bs.Log.Debug("Fetching template for id %s", arg.StackTemplateID)

	if err := bs.Builder.BuildStackTemplate(arg.StackTemplateID); err != nil {
		return nil, err
	}

	bs.Log.Debug("Fetching credentials for id %v", bs.Builder.StackTemplate.Credentials)

	credIDs := FlattenValues(bs.Builder.StackTemplate.Credentials)

	var cred *stack.Credential
	err := bs.Builder.BuildCredentials(bs.Req.Method, bs.Req.Username, arg.GroupName, credIDs)
	switch {
	case models.IsNotFound(err, "jCredential"):
		cred = &stack.Credential{
			Provider: bs.Provider.Name,
		}

		// If no credentials were sent with the request, use a blank one
		// when extending the template.
		initCreds(cred)
	case err != nil:
		return nil, err
	default:
		cred, err = bs.Builder.CredentialByProvider(bs.Provider.Name)
		if err != nil {
			return nil, err
		}
	}

	if err := bs.Builder.Authorize(bs.Req.Username); err != nil {
		return nil, err
	}

	bs.Log.Debug("Fetched terraform data: koding=%+v, template=%+v", bs.Builder.Koding, bs.Builder.Template)

	contentID := bs.Req.Username + "-" + arg.StackTemplateID

	bs.Log.Debug("Stack template before plan: %s", contentID, util.LazyJSON(bs.Builder.StackTemplate.Template.Content))

	if err := bs.Builder.BuildTemplate(bs.Builder.StackTemplate.Template.Content, contentID); err != nil {
		return nil, err
	}

	t, err := bs.stack.ApplyTemplate(cred)
	if err != nil {
		return nil, err
	}

	bs.Log.Debug("Stack template after injecting Koding data: %s", t)

	// Plan request is made right away the template is saved, it may
	// not have all the credentials provided yet. We set them all to
	// to dummy values to make the template pass terraform parsing.
	for _, name := range escapeVars {
		if err := bs.Builder.Template.FillVariables(name); err != nil {
			return nil, err
		}
	}

	if len(arg.Variables) != 0 {
		if err := bs.Builder.Template.InjectVariables("", arg.Variables); err != nil {
			return nil, err
		}
	}

	machines, err := bs.plan()
	if err != nil {
		return nil, err
	}

	bs.Log.Debug("Machines planned to be created: %+v", machines)

	return &stack.PlanResponse{
		Machines: machines.Slice(),
	}, nil
}

func (bs *BaseStack) Plan() (stack.Machines, error) {
	out, err := bs.Builder.Template.JsonOutput()
	if err != nil {
		return nil, err
	}

	tfKite, err := terraformer.Connect(bs.Session.Terraformer)
	if err != nil {
		return nil, err
	}
	defer tfKite.Close()

	tfReq := &tf.TerraformRequest{
		Content:   out,
		ContentID: bs.Req.Username + "-" + bs.Arg.(*stack.PlanRequest).StackTemplateID,
		TraceID:   bs.TraceID,
	}

	bs.Log.Debug("Calling plan with content: %+v", tfReq)

	plan, err := tfKite.Plan(tfReq)
	if err != nil {
		return nil, err
	}

	return bs.Planner.MachinesFromPlan(plan)
}
