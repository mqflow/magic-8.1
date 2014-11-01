/*
 * ----------------------------------------------------------------------------
 *
 * spcnodeVisit --
 *
 * Procedure to output a single node to the .spice file along with its 
 * attributes and its dictionary (if present). Called by EFVisitNodes().
 *
 * Results:
 *	Returns 0 always.
 *
 * Side effects:
 *	Writes to the files esSpiceF
 *
 * ----------------------------------------------------------------------------
 */

int
spcnodeVisit(node, res, cap)
    EFNode *node;
    int res; 
    double cap;
{
    EFNodeName *nn;
    HierName *hierName;
    bool isConnected = FALSE;
    char *fmt, *nsn;
    EFAttr *ap;

    if (node->efnode_client)
    {
	isConnected = (esDistrJunct) ?
		(((nodeClient *)node->efnode_client)->m_w.widths != NULL) :
        	((((nodeClient *)node->efnode_client)->m_w.visitMask
		& DEV_CONNECT_MASK) != 0);
    }
    if (!isConnected && esDevNodesOnly) 
	return 0;

    /* Don't mark known ports as "FLOATING" nodes */
    if (!isConnected && node->efnode_flags & EF_PORT) isConnected = TRUE;

    hierName = (HierName *) node->efnode_name->efnn_hier;
    nsn = nodeSpiceName(hierName);

    if (esFormat == SPICE2 || esFormat == HSPICE && strncmp(nsn, "z@", 2)==0 ) {
	static char ntmp[MAX_STR_SIZE];

	EFHNSprintf(ntmp, hierName);
	fprintf(esSpiceF, "** %s == %s\n", ntmp, nsn);
    }
    cap = cap  / 1000;
    if (cap > EFCapThreshold)
    {
	fprintf(esSpiceF, esSpiceCapFormat, esCapNum++, nsn, cap,
			  (isConnected) ?  "\n" : " **FLOATING\n");
    }
    if (node->efnode_attrs && !esNoAttrs)
    {
	fprintf(esSpiceF, "**nodeattr %s :",nsn );
	for (fmt = " %s", ap = node->efnode_attrs; ap; ap = ap->efa_next)
	{
	    fprintf(esSpiceF, fmt, ap->efa_text);
	    fmt = ",%s";
	}
	putc('\n', esSpiceF);
    }

    return 0;
}

